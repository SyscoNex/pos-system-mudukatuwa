using Conex360.Application.Inventory;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    internal static async Task RequireNoOpenLocationOperations(MySqlConnection c, MySqlTransaction t, Membership member,
        ulong? warehouse, ulong? branch, CancellationToken ct)
    {
        if (!await OperationsInstalled(c, t, ct)) return;
        var open = await Sql.Scalar(c, t, """
            SELECT 1 FROM warehouses w
            WHERE w.tenant_id=@tenant AND w.company_id=@company
              AND (@warehouse IS NULL OR w.id=@warehouse) AND (@branch IS NULL OR w.branch_id=@branch)
              AND (EXISTS (SELECT 1 FROM stock_counts c WHERE c.tenant_id=w.tenant_id AND c.company_id=w.company_id AND c.active_warehouse_id=w.id)
                OR EXISTS (
                  SELECT 1 FROM stock_transfers x
                  WHERE x.tenant_id=w.tenant_id AND x.company_id=w.company_id
                    AND (x.source_warehouse_id=w.id OR x.destination_warehouse_id=w.id)
                    AND (EXISTS (
                      SELECT 1 FROM document_lines l WHERE l.tenant_id=x.tenant_id AND l.company_id=x.company_id AND l.document_id=x.request_id
                       AND x.cancellation_id IS NULL AND l.base_quantity>COALESCE((
                         SELECT SUM(a.quantity) FROM transfer_dispatch_allocations a JOIN stock_reservations r
                          ON r.tenant_id=a.tenant_id AND r.company_id=a.company_id AND r.id=a.reservation_id
                         WHERE r.tenant_id=x.tenant_id AND r.company_id=x.company_id AND r.request_line_id=l.id AND r.request_id=x.request_id),0))
                    OR EXISTS (
                      SELECT 1 FROM transfer_dispatch_allocations a JOIN stock_reservations r
                        ON r.tenant_id=a.tenant_id AND r.company_id=a.company_id AND r.id=a.reservation_id
                      WHERE r.tenant_id=x.tenant_id AND r.company_id=x.company_id AND r.request_id=x.request_id AND
                        a.quantity>COALESCE((SELECT SUM(y.quantity) FROM transfer_receipt_allocations y WHERE y.tenant_id=a.tenant_id AND y.company_id=a.company_id AND y.dispatch_allocation_id=a.id),0)
                          +COALESCE((SELECT SUM(y.quantity) FROM transfer_resolution_allocations y WHERE y.tenant_id=a.tenant_id AND y.company_id=a.company_id AND y.dispatch_allocation_id=a.id),0)))))
            LIMIT 1
            """, ct, ("tenant", member.TenantId), ("company", member.CompanyId), ("warehouse", warehouse), ("branch", branch));
        if (open is not null) throw Conflict("Resolve open transfers and active stock takes before deactivating this location.");
    }

    internal static async Task RequireNoOpenItemRequests(MySqlConnection c, MySqlTransaction t, Membership member,
        ulong item, CancellationToken ct)
    {
        if (!await OperationsInstalled(c, t, ct)) return;
        var found = await Sql.Scalar(c, t, """
            SELECT 1 FROM stock_transfers x JOIN document_lines l ON l.tenant_id=x.tenant_id AND l.company_id=x.company_id AND l.document_id=x.request_id
            WHERE l.tenant_id=@tenant AND l.company_id=@company AND l.item_id=@item AND x.cancellation_id IS NULL
              AND l.base_quantity>COALESCE((
                SELECT SUM(a.quantity) FROM stock_reservations r JOIN transfer_dispatch_allocations a
                ON a.tenant_id=r.tenant_id AND a.company_id=r.company_id AND a.reservation_id=r.id
                WHERE r.tenant_id=l.tenant_id AND r.company_id=l.company_id AND r.request_id=l.document_id AND r.request_line_id=l.id),0)
            LIMIT 1
            """, ct, ("tenant", member.TenantId), ("company", member.CompanyId), ("item", item));
        if (found is not null) throw Conflict("Resolve outstanding transfer requests before deactivating this product.");
    }

    public Task<IReadOnlyList<StockOperationDifference>> ReconcileOperationsAsync(SessionData session, CancellationToken ct) =>
        Operate(session, true, s => s.List("""
            WITH settled AS (
              SELECT dispatch_allocation_id,SUM(quantity) quantity,SUM(carried_value) carried_value FROM (
                SELECT dispatch_allocation_id,quantity,carried_value FROM transfer_receipt_allocations WHERE tenant_id=@tenant AND company_id=@company
                UNION ALL
                SELECT dispatch_allocation_id,quantity,carried_value FROM transfer_resolution_allocations WHERE tenant_id=@tenant AND company_id=@company
              ) x GROUP BY dispatch_allocation_id
            ), remaining AS (
              SELECT a.id,a.transit_bucket_id,a.quantity-COALESCE(x.quantity,0) quantity,a.carried_value-COALESCE(x.carried_value,0) carried_value
              FROM transfer_dispatch_allocations a LEFT JOIN settled x ON x.dispatch_allocation_id=a.id
              WHERE a.tenant_id=@tenant AND a.company_id=@company
            ), transit AS (
              SELECT transit_bucket_id,SUM(quantity) quantity,SUM(carried_value) carried_value FROM remaining GROUP BY transit_bucket_id
            ), reserved AS (
              SELECT bucket_id,SUM(reserved_quantity-consumed_quantity-released_quantity) quantity
              FROM stock_reservations WHERE tenant_id=@tenant AND company_id=@company GROUP BY bucket_id
            ), shipped AS (
              SELECT a.reservation_id,SUM(a.quantity) quantity FROM transfer_dispatch_allocations a
              WHERE a.tenant_id=@tenant AND a.company_id=@company GROUP BY a.reservation_id
            ), requested AS (
              SELECT request_id,request_line_id,SUM(reserved_quantity) quantity,SUM(consumed_quantity) consumed,SUM(released_quantity) released
              FROM stock_reservations WHERE tenant_id=@tenant AND company_id=@company GROUP BY request_id,request_line_id
            ), ledger AS (
              SELECT bucket_id,SUM(quantity_base) quantity,SUM(value_delta) carried_value,MAX(id) last_entry_id
              FROM stock_entries WHERE tenant_id=@tenant AND company_id=@company GROUP BY bucket_id
            ), legs AS (
              SELECT 'DISPATCH_LEGS' kind,a.id,a.source_entry_id issue_id,a.transit_entry_id gain_id,a.quantity,a.carried_value
               FROM transfer_dispatch_allocations a WHERE a.tenant_id=@tenant AND a.company_id=@company
              UNION ALL
              SELECT 'RECEIPT_LEGS',a.receipt_id,a.transit_entry_id,a.destination_entry_id,a.quantity,a.carried_value
               FROM transfer_receipt_allocations a WHERE a.tenant_id=@tenant AND a.company_id=@company
              UNION ALL
              SELECT 'RESOLUTION_LEGS',a.resolution_id,a.transit_entry_id,a.destination_entry_id,a.quantity,a.carried_value
               FROM transfer_resolution_allocations a WHERE a.tenant_id=@tenant AND a.company_id=@company
            )
            SELECT kind,id FROM (
              SELECT 'LEDGER' AS kind,k.id FROM stock_buckets k
              LEFT JOIN ledger l ON l.bucket_id=k.id
              LEFT JOIN stock_balances b ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
              WHERE k.tenant_id=@tenant AND k.company_id=@company
                AND (NOT(l.quantity <=> b.on_hand_base) OR NOT(l.carried_value <=> b.operational_value) OR NOT(l.last_entry_id <=> b.last_entry_id))
              UNION ALL
              SELECT 'RESERVATION',r.bucket_id FROM reserved r LEFT JOIN stock_balances b
                ON b.tenant_id=@tenant AND b.company_id=@company AND b.bucket_id=r.bucket_id
              WHERE r.quantity<0 OR r.quantity>COALESCE(b.on_hand_base,0)
              UNION ALL
              SELECT 'DISPATCH',r.id FROM stock_reservations r LEFT JOIN shipped a ON a.reservation_id=r.id
              WHERE r.tenant_id=@tenant AND r.company_id=@company AND r.consumed_quantity<>COALESCE(a.quantity,0)
              UNION ALL
              SELECT 'REQUEST',l.id FROM stock_transfers t JOIN document_lines l ON l.tenant_id=t.tenant_id AND l.company_id=t.company_id AND l.document_id=t.request_id
              LEFT JOIN requested q ON q.request_id=t.request_id AND q.request_line_id=l.id
              WHERE t.tenant_id=@tenant AND t.company_id=@company
                AND ((t.confirmation_id IS NOT NULL AND l.base_quantity<>COALESCE(q.quantity,0))
                  OR (t.cancellation_id IS NOT NULL AND COALESCE(q.consumed,0)+COALESCE(q.released,0)<>COALESCE(q.quantity,0)))
              UNION ALL
              SELECT 'ALLOCATION',id FROM remaining WHERE quantity<0 OR carried_value<0 OR (quantity=0 AND carried_value<>0)
              UNION ALL
              SELECT a.kind,a.id FROM legs a
              LEFT JOIN stock_entries e ON e.tenant_id=@tenant AND e.company_id=@company AND e.id=a.issue_id
              LEFT JOIN stock_entries g ON g.tenant_id=@tenant AND g.company_id=@company AND g.id=a.gain_id
              WHERE e.id IS NULL OR e.quantity_base<>-a.quantity OR e.value_delta<>-a.carried_value
                OR (a.gain_id IS NOT NULL AND (g.id IS NULL OR g.quantity_base<>a.quantity OR g.value_delta<>a.carried_value
                    OR g.item_id<>e.item_id OR g.lot_id<>e.lot_id))
              UNION ALL
              SELECT 'TRANSIT',k.id FROM stock_buckets k LEFT JOIN transit t ON t.transit_bucket_id=k.id
              LEFT JOIN stock_balances b ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
              WHERE k.tenant_id=@tenant AND k.company_id=@company AND k.stock_condition='TRANSIT'
                AND (COALESCE(t.quantity,0)<>COALESCE(b.on_hand_base,0) OR COALESCE(t.carried_value,0)<>COALESCE(b.operational_value,0))
              UNION ALL
              SELECT 'COUNT',c.count_id FROM stock_counts c JOIN stock_count_lines l
                ON l.tenant_id=c.tenant_id AND l.company_id=c.company_id AND l.count_id=c.count_id
              LEFT JOIN stock_entries e ON e.tenant_id=l.tenant_id AND e.company_id=l.company_id AND e.id=l.variance_entry_id
              WHERE c.tenant_id=@tenant AND c.company_id=@company AND
                ((c.status<>'COMPLETED' AND e.id IS NOT NULL) OR
                  (c.status='COMPLETED' AND (l.actual_quantity IS NULL OR
                    (l.actual_quantity=l.expected_quantity AND e.id IS NOT NULL) OR
                    (l.actual_quantity<>l.expected_quantity AND (e.id IS NULL OR e.document_id<>c.terminal_id OR e.quantity_base<>l.actual_quantity-l.expected_quantity)))))
            ) findings ORDER BY kind,id LIMIT 100
            """,
            r => new StockOperationDifference(r.GetString(0), r.GetUInt64(1))), ct);
}

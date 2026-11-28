using Conex360.Application.Inventory;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    private const string ProductionSelect = """
        SELECT d.id,d.document_number,d.warehouse_id,d.warehouse_name,d.business_date,p.production_reference,
          o.sku,o.item_name,o.entered_quantity,o.unit_code,o.base_quantity,o.lot_id,o.lot_code,
          l.tracking_mode,o.expires_on,d.currency_code,
          CASE WHEN @admin=1 THEN d.operational_total END AS visible_total,u.display_name,d.notes
        FROM production_events p
        JOIN documents d ON d.tenant_id=p.tenant_id AND d.company_id=p.company_id AND d.id=p.document_id
        JOIN warehouses w ON w.tenant_id=p.tenant_id AND w.company_id=p.company_id AND w.id=p.warehouse_id
        JOIN document_lines o ON o.tenant_id=p.tenant_id AND o.company_id=p.company_id AND o.document_id=p.document_id AND o.id=p.output_line_id
        JOIN lots l ON l.tenant_id=o.tenant_id AND l.company_id=o.company_id AND l.item_id=o.item_id AND l.id=o.lot_id
        JOIN tenant_memberships m ON m.tenant_id=d.tenant_id AND m.id=d.actor_membership_id
        JOIN users u ON u.id=m.user_id
        WHERE
        """;

    private static ProductionRun ReadProductionRun(MySqlDataReader r)
    {
        var total = Amount(r, "visible_total");
        var quantity = r.GetDecimal("base_quantity");
        return new(r.GetUInt64("id"), r.GetString("document_number"), r.GetUInt64("warehouse_id"), r.GetString("warehouse_name"),
            Day(r, "business_date")!.Value, Sql.Text(r, "production_reference"), r.GetString("sku"), r.GetString("item_name"),
            r.GetDecimal("entered_quantity"), r.GetString("unit_code"), quantity, r.GetUInt64("lot_id"), r.GetString("lot_code"),
            r.GetString("tracking_mode") == "LOT", Day(r, "expires_on"), r.GetString("currency_code"), total,
            total.HasValue ? AverageProductionCost(total.Value, quantity) : null);
    }

    public Task<IReadOnlyList<ProductionRun>> ProductionRunsAsync(SessionData session, ulong? warehouse, ulong? inputLot,
        ulong? outputLot, ulong? before, CancellationToken ct) =>
        Manufacture(session, false, s => s.List(ProductionSelect + WarehouseAccess + """
             AND (@warehouse IS NULL OR w.id=@warehouse) AND (@before IS NULL OR p.document_id<@before)
             AND (@outputLot IS NULL OR (p.output_lot_id=@outputLot AND l.tracking_mode='LOT'))
             AND (@inputLot IS NULL OR EXISTS (
               SELECT 1 FROM document_lines i JOIN lots material
                 ON material.tenant_id=i.tenant_id AND material.company_id=i.company_id AND material.item_id=i.item_id AND material.id=i.lot_id
               WHERE i.tenant_id=p.tenant_id AND i.company_id=p.company_id AND i.document_id=p.document_id
                 AND i.production_role='INPUT' AND i.lot_id=@inputLot AND material.tracking_mode='LOT'))
             ORDER BY p.document_id DESC LIMIT 50
            """, ReadProductionRun, ("warehouse", warehouse), ("inputLot", inputLot), ("outputLot", outputLot), ("before", before)), ct);

    public Task<ProductionDetail> ProductionAsync(SessionData session, ulong id, CancellationToken ct) =>
        Manufacture(session, false, async s =>
        {
            var header = await s.One(ProductionSelect + WarehouseAccess + " AND p.document_id=@id",
                r => new { Run = ReadProductionRun(r), Operator = r.GetString("display_name"), Notes = Sql.Text(r, "notes") }, ("id", id))
                ?? throw Missing();
            var materials = await s.List("""
                SELECT production_input_group,sku,item_name,unit_code,entered_quantity,conversion_factor,
                  base_quantity,lot_id,lot_code,expires_on,CASE WHEN @admin=1 THEN carried_value END AS visible_value
                FROM document_lines
                WHERE tenant_id=@tenant AND company_id=@company AND document_id=@id AND production_role='INPUT'
                ORDER BY production_input_group,line_number
                """, r => new ProductionAllocation(r.GetInt32(0), r.GetString(1), r.GetString(2), r.GetString(3),
                    r.GetDecimal(4), r.GetDecimal(5), r.GetDecimal(6), r.GetUInt64(7), r.GetString(8), Day(r, "expires_on"),
                    Amount(r, "visible_value")), ("id", id));
            return new ProductionDetail(header.Run, header.Operator, header.Notes, materials);
        }, ct);

    private static Task<IReadOnlyList<StockOperationDifference>> ProductionDifferences(Scope s) =>
        s.List("""
            WITH production_lines AS (
              SELECT d.id AS production_id,l.id AS line_id,l.production_role,l.production_input_group,l.entered_quantity,l.conversion_factor,
                l.item_unit_id,l.base_quantity,l.carried_value,COUNT(e.id) AS entry_count,
                SUM(e.quantity_base) AS quantity,SUM(e.value_delta) AS carried,
                MAX(e.id) AS entry_id
              FROM documents d
              JOIN document_lines l ON l.tenant_id=d.tenant_id AND l.company_id=d.company_id AND l.document_id=d.id
              LEFT JOIN stock_entries e ON e.tenant_id=l.tenant_id AND e.company_id=l.company_id AND e.document_id=l.document_id AND e.line_id=l.id
              WHERE d.tenant_id=@tenant AND d.company_id=@company AND d.document_type='PROD'
              GROUP BY d.id,l.id,l.production_role,l.production_input_group,l.entered_quantity,l.conversion_factor,l.item_unit_id,l.base_quantity,l.carried_value
            ), runs AS (
              SELECT production_id, SUM(production_role='INPUT') AS inputs,SUM(production_role='OUTPUT') AS outputs,
                SUM(CASE WHEN production_role='INPUT' THEN carried_value ELSE 0 END) AS input_value,
                SUM(CASE WHEN production_role='OUTPUT' THEN carried_value ELSE 0 END) AS output_value,
                MAX(CASE WHEN production_role='OUTPUT' THEN line_id END) AS output_line,
                MAX(CASE WHEN production_role='OUTPUT' THEN entry_id END) AS output_entry,
                SUM(CASE WHEN entry_count<>1 OR production_role IS NULL
                  OR NOT (quantity <=> CASE WHEN production_role='INPUT' THEN -base_quantity ELSE base_quantity END)
                  OR NOT (carried <=> CASE WHEN production_role='INPUT' THEN -carried_value ELSE carried_value END)
                  THEN 1 ELSE 0 END) AS errors
              FROM production_lines GROUP BY production_id
            ), input_groups AS (
              SELECT production_id,production_input_group,
                SUM(base_quantity) AS quantity,MIN(entered_quantity*conversion_factor) AS expected,
                COUNT(DISTINCT entered_quantity,conversion_factor,item_unit_id) AS variations
              FROM production_lines WHERE production_role='INPUT' GROUP BY production_id,production_input_group
            )
            SELECT 'PRODUCTION',d.id
            FROM documents d JOIN warehouses w ON w.tenant_id=d.tenant_id AND w.company_id=d.company_id AND w.id=d.warehouse_id
            LEFT JOIN production_events p ON p.tenant_id=d.tenant_id AND p.company_id=d.company_id AND p.document_id=d.id
            LEFT JOIN runs r ON r.production_id=d.id
            WHERE
            """ + WarehouseAccess + """
             AND d.document_type='PROD' AND (p.document_id IS NULL OR r.production_id IS NULL OR r.inputs<1 OR r.outputs<>1 OR r.errors<>0
               OR r.input_value<>r.output_value OR r.output_value<>d.operational_total
               OR NOT(r.output_line <=> p.output_line_id) OR NOT(r.output_entry <=> p.output_entry_id)
               OR EXISTS (SELECT 1 FROM input_groups g WHERE g.production_id=d.id AND (g.quantity<>g.expected OR g.variations<>1)))
             ORDER BY d.id LIMIT 100
            """, r => new StockOperationDifference(r.GetString(0), r.GetUInt64(1)));

    public Task<IReadOnlyList<StockOperationDifference>> ReconcileProductionAsync(SessionData session, CancellationToken ct) =>
        Manufacture<IReadOnlyList<StockOperationDifference>>(session, true, async s =>
        [
            .. await ProductionDifferences(s),
            .. (await BalanceDifferences(s, null, null)).Select(x => new StockOperationDifference("LEDGER", x.BucketId))
        ], ct);
}

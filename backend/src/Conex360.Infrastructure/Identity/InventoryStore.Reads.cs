using Conex360.Application.Inventory;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    public Task<IReadOnlyList<StockRow>> StockAsync(SessionData session, StockQuery query, CancellationToken ct) =>
        InScope(session, false, async s =>
        {
            if (query.Expiry is not (null or "expired" or "dated" or "undated"))
                throw Invalid("Select a supported expiry filter.");
            var today = (await Business(s)).Today;
            var reservedSql = await OperationsInstalled(s.Connection, s.Transaction, s.Ct)
                ? "(SELECT COALESCE(SUM(r.reserved_quantity-r.consumed_quantity-r.released_quantity),0) FROM stock_reservations r WHERE r.tenant_id=k.tenant_id AND r.company_id=k.company_id AND r.bucket_id=k.id)"
                : "CAST(0 AS DECIMAL(24,9))";
            return await s.List("""
                SELECT k.id,k.item_id,k.warehouse_id,w.name AS warehouse,i.sku,i.name AS product,u.code AS base_unit,l.lot_code,l.manufactured_on,l.expires_on,
                  k.stock_condition,l.is_blocked,b.on_hand_base,CASE WHEN @admin=1 THEN b.operational_value END AS visible_value,
                """ + " " + reservedSql + """
                 AS reserved
                FROM stock_buckets k JOIN stock_balances b ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
                JOIN warehouses w ON w.tenant_id=k.tenant_id AND w.company_id=k.company_id AND w.id=k.warehouse_id
                JOIN lots l ON l.tenant_id=k.tenant_id AND l.company_id=k.company_id AND l.item_id=k.item_id AND l.id=k.lot_id
                JOIN items i ON i.tenant_id=k.tenant_id AND i.company_id=k.company_id AND i.id=k.item_id
                JOIN units u ON u.tenant_id=i.tenant_id AND u.company_id=i.company_id AND u.id=i.base_unit_id
                WHERE
                """ + WarehouseAccess + """
                 AND k.id>@after AND (@warehouse IS NULL OR w.id=@warehouse) AND (@item IS NULL OR i.id=@item)
                 AND (@category IS NULL OR i.category_id=@category) AND (@batch IS NULL OR l.lot_code=@batch)
                 AND (@expiry IS NULL OR (@expiry='expired' AND l.expires_on<@today)
                    OR (@expiry='dated' AND l.expires_on IS NOT NULL) OR (@expiry='undated' AND l.expires_on IS NULL))
                ORDER BY k.id LIMIT 50
                """, r =>
            {
                var expiry = Day(r, "expires_on");
                var expired = expiry < today;
                var blocked = r.GetBoolean("is_blocked");
                var condition = r.GetString("stock_condition");
                var quantity = r.GetDecimal("on_hand_base");
                var reserved = r.GetDecimal("reserved");
                var value = Amount(r, "visible_value");
                decimal? average = quantity == 0 || value is null ? null :
                    decimal.Round(value.Value / quantity, 6, MidpointRounding.AwayFromZero);
                return new StockRow(r.GetUInt64("id"), r.GetUInt64("warehouse_id"), r.GetString("warehouse"), r.GetString("sku"),
                    r.GetString("product"), r.GetString("base_unit"), r.GetString("lot_code"), Day(r, "manufactured_on"), expiry,
                    condition, blocked, expired, quantity, condition == "AVAILABLE" && !blocked && !expired ? quantity - reserved : 0, value, average)
                { Reserved = reserved, ItemId = r.GetUInt64("item_id") };
            }, ("after", query.After ?? 0), ("warehouse", query.WarehouseId), ("item", query.ItemId), ("category", query.CategoryId),
                ("batch", Clean(query.Batch, 128)), ("expiry", query.Expiry), ("today", today));
        }, ct);

    private static decimal? Amount(MySqlDataReader r, string name) => r[name] is DBNull ? null : r.GetDecimal(name);

    private const string DocumentQuery = """
        SELECT d.id,d.document_number,d.document_type,d.warehouse_name,d.business_date,d.posted_at,d.currency_code,d.currency_minor_units,
          CASE WHEN @admin=1 THEN d.operational_total END AS visible_total,d.notes,g.supplier_name,g.supplier_reference
        FROM documents d
        JOIN warehouses w ON w.tenant_id=d.tenant_id AND w.company_id=d.company_id AND w.id=d.warehouse_id
        LEFT JOIN goods_receipts g ON g.tenant_id=d.tenant_id AND g.company_id=d.company_id AND g.document_id=d.id
        WHERE
        """;

    private static ReceiptSummary Summary(MySqlDataReader r)
    {
        var total = Amount(r, "visible_total");
        return new(r.GetUInt64("id"), r.GetString("document_number"), r.GetString("document_type"), r.GetString("warehouse_name"),
            Day(r, "business_date")!.Value, Sql.Date(r, "posted_at")!.Value, r.GetString("currency_code"),
            Sql.Text(r, "supplier_name"), Sql.Text(r, "supplier_reference"),
            total is null ? null : decimal.Round(total.Value, r.GetByte("currency_minor_units"), MidpointRounding.AwayFromZero));
    }

    public Task<IReadOnlyList<ReceiptSummary>> DocumentsAsync(SessionData session, ulong? warehouseId, string? type, ulong? before, CancellationToken ct) =>
        InScope(session, false, s => s.List(DocumentQuery + WarehouseAccess +
            " AND (@warehouse IS NULL OR w.id=@warehouse) AND (@type IS NULL OR d.document_type=@type) AND (@before IS NULL OR d.id<@before) ORDER BY d.id DESC LIMIT 50",
            Summary, ("warehouse", warehouseId), ("type", type), ("before", before)), ct);

    public Task<ReceiptDetail> DocumentAsync(SessionData session, ulong id, CancellationToken ct) =>
        InScope(session, false, async s =>
        {
            var header = await s.One(DocumentQuery + WarehouseAccess + " AND d.id=@id",
                r => new { Document = Summary(r), Notes = Sql.Text(r, "notes") }, ("id", id)) ?? throw Missing();
            var lines = await s.List("""
                SELECT sku,item_name,unit_name,lot_code,supplier_lot,manufactured_on,expires_on,stock_condition,entered_quantity,
                  conversion_factor,base_quantity,CASE WHEN @admin=1 AND @type<>'PROD' THEN entered_unit_cost END AS visible_cost,
                  CASE WHEN @admin=1 THEN carried_value END AS visible_value
                FROM document_lines WHERE tenant_id=@tenant AND company_id=@company AND document_id=@id ORDER BY line_number
                """, r => new PostedLine(r.GetString("sku"), r.GetString("item_name"), r.GetString("unit_name"), r.GetString("lot_code"),
                Sql.Text(r, "supplier_lot"), Day(r, "manufactured_on"), Day(r, "expires_on"), r.GetString("stock_condition"),
                r.GetDecimal("entered_quantity"), r.GetDecimal("conversion_factor"), r.GetDecimal("base_quantity"),
                Amount(r, "visible_cost"), Amount(r, "visible_value")), ("id", id), ("type", header.Document.Type));
            return new ReceiptDetail(header.Document, header.Notes, lines);
        }, ct);

    public Task<IReadOnlyList<StockMovement>> MovementsAsync(SessionData session, ulong? warehouseId, ulong? before, CancellationToken ct) =>
        InScope(session, false, s => s.List("""
            SELECT e.id,e.document_id,d.document_number,d.warehouse_name,dl.sku,dl.lot_code,e.stock_condition,d.posted_at,e.quantity_base,
                CASE WHEN @admin=1 THEN e.value_delta END AS visible_value
            FROM stock_entries e
            JOIN documents d ON d.tenant_id=e.tenant_id AND d.company_id=e.company_id AND d.id=e.document_id
            JOIN document_lines dl ON dl.tenant_id=e.tenant_id AND dl.company_id=e.company_id AND dl.document_id=e.document_id AND dl.id=e.line_id
            JOIN warehouses w ON w.tenant_id=e.tenant_id AND w.company_id=e.company_id AND w.id=e.warehouse_id
            WHERE
            """ + WarehouseAccess + " AND (@warehouse IS NULL OR w.id=@warehouse) AND (@before IS NULL OR e.id<@before) ORDER BY e.id DESC LIMIT 50",
            r => new StockMovement(r.GetUInt64("id"), r.GetUInt64("document_id"), r.GetString("document_number"), r.GetString("warehouse_name"),
                r.GetString("sku"), r.GetString("lot_code"), r.GetString("stock_condition"), Sql.Date(r, "posted_at")!.Value,
                r.GetDecimal("quantity_base"), Amount(r, "visible_value")), ("warehouse", warehouseId), ("before", before)), ct);

    public Task<IReadOnlyList<BalanceDifference>> ReconcileAsync(SessionData session, ulong? warehouseId, ulong? after, CancellationToken ct) =>
        InScope(session, true, s => BalanceDifferences(s, warehouseId, after), ct);

    private static Task<IReadOnlyList<BalanceDifference>> BalanceDifferences(Scope s, ulong? warehouseId, ulong? after) =>
        s.List("""
            SELECT k.id,COALESCE(SUM(e.quantity_base),0) AS ledger_quantity,COALESCE(SUM(e.value_delta),0) AS ledger_value,
                b.on_hand_base,b.operational_value
            FROM stock_buckets k
            JOIN warehouses w ON w.tenant_id=k.tenant_id AND w.company_id=k.company_id AND w.id=k.warehouse_id
            LEFT JOIN stock_entries e ON e.tenant_id=k.tenant_id AND e.company_id=k.company_id AND e.bucket_id=k.id
            LEFT JOIN stock_balances b ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
            WHERE
            """ + WarehouseAccess + """
             AND k.id>@after AND (@warehouse IS NULL OR w.id=@warehouse)
            GROUP BY k.id,b.on_hand_base,b.operational_value,b.last_entry_id
            HAVING NOT (ledger_quantity <=> b.on_hand_base) OR NOT (ledger_value <=> b.operational_value)
                OR NOT (MAX(e.id) <=> b.last_entry_id)
            ORDER BY k.id LIMIT 50
            """, r => new BalanceDifference(r.GetUInt64("id"), r.GetDecimal("ledger_quantity"), Amount(r, "on_hand_base"),
                r.GetDecimal("ledger_value"), Amount(r, "operational_value")), ("warehouse", warehouseId), ("after", after ?? 0));
}

using System.Security.Cryptography;
using System.Text.Json;
using Conex360.Application.Identity;
using Conex360.Application.Inventory;
using Conex360.Domain.Catalog;
using Conex360.Domain.Identity;
using Conex360.Domain.Inventory;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore
{
    private static async Task RequireUnfrozen(Scope s, params ulong[] warehouseIds)
    {
        if (!await OperationsInstalled(s.Connection, s.Transaction, s.Ct)) return;
        foreach (var id in warehouseIds.Distinct().Order())
            if (await s.Scalar("""
                SELECT 1 FROM stock_counts WHERE tenant_id=@tenant AND company_id=@company AND active_warehouse_id=@id
                """, ("id", id)) is not null)
                throw Conflict("This warehouse has an active stock take.");
    }

    internal static async Task<bool> OperationsInstalled(MySqlConnection c, MySqlTransaction t, CancellationToken ct) =>
        await Sql.Scalar(c, t, "SELECT 1 FROM schema_migrations WHERE version=11", ct) is not null;

    private Task<T> Operate<T>(SessionData session, bool admin, Func<Scope, Task<T>> action, CancellationToken ct) =>
        InScope(session, admin, s =>
        {
            if (!settings.StockOperationsEnabled) throw new AppFailure(503, "STOCK_OPERATIONS_DISABLED", "Stock operations are not enabled.");
            return action(s);
        }, ct);

    private static async Task<Warehouse> Ordinary(Scope s, ulong id, bool authorize = true)
    {
        Warehouse? warehouse;
        if (authorize) warehouse = await FindWarehouse(s, id);
        else warehouse = await s.One("""
            SELECT w.id,w.branch_id,w.row_version,w.name,w.code,(w.is_active AND b.is_active)
            FROM warehouses w JOIN branches b ON b.tenant_id=w.tenant_id AND b.company_id=w.company_id AND b.id=w.branch_id
            WHERE w.tenant_id=@tenant AND w.company_id=@company AND w.id=@id AND w.kind='ORDINARY'
            """, r => new Warehouse(r.GetUInt64(0), r.GetUInt64(1), r.GetUInt64(2), r.GetString(3), r.GetString(4), r.GetBoolean(5)), ("id", id));
        return warehouse is { Active: true } ? warehouse : throw Missing();
    }

    private static async Task<Warehouse> Transit(Scope s) =>
        await s.One("""
            SELECT id,row_version,name,code FROM warehouses WHERE tenant_id=@tenant AND company_id=@company AND kind='TRANSIT' AND is_active=1
            """, r => new Warehouse(r.GetUInt64(0), 0, r.GetUInt64(1), r.GetString(2), r.GetString(3), true)) ??
        throw Conflict("The company transit warehouse is unavailable.");

    private static string Reason(string? value) => Clean(value, 300) ?? throw Invalid("Enter a reason.");

    private static byte[] OperationHash<T>(ulong target, T input) =>
        SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(new { version = 1, target, input }, OperationJson));

    private static readonly JsonSerializerOptions OperationJson = new()
    {
        Converters = { new CanonicalOperationDecimal() }
    };

    private sealed class CanonicalOperationDecimal : System.Text.Json.Serialization.JsonConverter<decimal>
    {
        public override decimal Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) => throw new NotSupportedException();
        public override void Write(Utf8JsonWriter writer, decimal value, JsonSerializerOptions options) =>
            writer.WriteStringValue(value.ToString("G29", System.Globalization.CultureInfo.InvariantCulture));
    }

    private static async Task<PostedReceipt?> OperationReplay(Scope s, string command, Guid key, byte[] hash)
    {
        if (key == Guid.Empty) throw Invalid("Provide an operation ID.");
        var existing = await s.One("""
            SELECT k.request_hash,d.id,d.document_number FROM idempotency_keys k JOIN documents d
              ON d.tenant_id=k.tenant_id AND d.company_id=k.company_id AND d.id=k.document_id
            WHERE k.tenant_id=@tenant AND k.company_id=@company AND k.actor_membership_id=@actor AND k.command=@command AND k.operation_key=@key
            """, r => new { Hash = (byte[])r[0], Result = new PostedReceipt(r.GetUInt64(1), r.GetString(2)) }, ("command", command), ("key", key));
        if (existing is not null && !CryptographicOperations.FixedTimeEquals(existing.Hash, hash))
            throw Conflict("The operation ID was already used with different input.");
        return existing?.Result;
    }

    private static async Task<PostedReceipt> Document(Scope s, Warehouse warehouse, string command, string? notes, decimal total = 0,
        DateOnly? businessDate = null)
    {
        var business = await Business(s);
        var date = businessDate ?? business.Today;
        var number = await NextNumber(s, command, date.Year);
        var id = await s.Insert("""
            INSERT INTO documents(tenant_id,company_id,document_type,document_number,warehouse_id,actor_membership_id,warehouse_name,warehouse_code,
              business_date,posted_at,currency_code,currency_minor_units,notes,operational_total)
            VALUES(@tenant,@company,@command,@number,@warehouse,@actor,@name,@code,@date,@now,@currency,@minor,@notes,@total)
            """, ("command", command), ("number", number), ("warehouse", warehouse.Id), ("name", warehouse.Name), ("code", warehouse.Code),
            ("date", date), ("now", s.Now), ("currency", business.Currency), ("minor", business.MinorUnits), ("notes", notes), ("total", total));
        return new(id, number);
    }

    private static async Task CompleteOperation(Scope s, PostedReceipt doc, string command, Guid key, byte[] hash, string reason, string correlation)
    {
        await IdentityStore.Audit(s.Connection, s.Transaction, s.Member, command, "DOCUMENT", doc.Id, reason, s.Now, correlation, s.Ct);
        await s.Execute("""
            INSERT INTO idempotency_keys(tenant_id,company_id,actor_membership_id,document_id,command,operation_key,request_hash)
            VALUES(@tenant,@company,@actor,@id,@command,@key,@hash)
            """, ("id", doc.Id), ("command", command), ("key", key), ("hash", hash));
    }

    private sealed record StockUnit(ulong Id, ulong ItemId, string Sku, string ItemName, string Code, string Name, decimal Factor, bool Discrete, bool BaseDiscrete);
    private static async Task<StockUnit> SelectUnit(Scope s, ulong item, ulong? unit, ulong? itemVersion = null, ulong? unitVersion = null, bool active = true)
    {
        var picked = await s.One("""
            SELECT iu.id,i.id,i.sku,i.name,u.code,u.name,iu.to_base_factor,u.is_discrete,bu.is_discrete,
              i.row_version,iu.row_version,(i.is_active AND iu.is_active AND u.is_active AND bu.is_active)
            FROM items i JOIN item_units iu ON iu.tenant_id=i.tenant_id AND iu.company_id=i.company_id AND iu.item_id=i.id
            JOIN units u ON u.tenant_id=iu.tenant_id AND u.company_id=iu.company_id AND u.id=iu.unit_id
            JOIN units bu ON bu.tenant_id=i.tenant_id AND bu.company_id=i.company_id AND bu.id=i.base_unit_id
            WHERE i.tenant_id=@tenant AND i.company_id=@company AND i.id=@item
              AND ((@unit IS NULL AND iu.unit_id=i.base_unit_id) OR iu.id=@unit)
            """, r => new
        {
            Unit = new StockUnit(r.GetUInt64(0), r.GetUInt64(1), r.GetString(2), r.GetString(3), r.GetString(4),
                r.GetString(5), r.GetDecimal(6), r.GetBoolean(7), r.GetBoolean(8)),
            ItemVersion = r.GetUInt64(9),
            UnitVersion = r.GetUInt64(10),
            Active = r.GetBoolean(11)
        }, ("item", item), ("unit", unit)) ?? throw Missing();
        if ((active && !picked.Active) || (itemVersion.HasValue && itemVersion != picked.ItemVersion) ||
            (unitVersion.HasValue && unitVersion != picked.UnitVersion))
            throw Conflict("The selected product or unit has changed.");
        return picked.Unit;
    }

    private static decimal ConvertQuantity(StockUnit unit, decimal quantity)
    {
        if (quantity <= 0) throw Invalid("Enter a positive quantity.");
        try { return CatalogNumbers.ToBase(quantity, unit.Factor, unit.Discrete, unit.BaseDiscrete); }
        catch (ArgumentException e) { throw Invalid(e.Message); }
    }

    private sealed record StockLot(ulong Id, string Code, string? Supplier, DateOnly? Manufactured, DateOnly? Expiry, bool Blocked);
    private sealed record Bucket(ulong Id, ulong Warehouse, ulong Item, string Condition, decimal Quantity,
        decimal Value, StockLot Lot);
    private const string BucketSelect = """
        SELECT k.id,k.warehouse_id,k.item_id,k.stock_condition,b.on_hand_base,b.operational_value,
          l.id AS lot_id,l.lot_code,l.supplier_lot,l.manufactured_on,l.expires_on,l.is_blocked
        FROM stock_buckets k JOIN stock_balances b ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
        JOIN lots l ON l.tenant_id=k.tenant_id AND l.company_id=k.company_id AND l.item_id=k.item_id AND l.id=k.lot_id
        WHERE k.tenant_id=@tenant AND k.company_id=@company
        """;
    private static Bucket ReadBucket(MySqlDataReader r) => new(r.GetUInt64(0), r.GetUInt64(1), r.GetUInt64(2), r.GetString(3),
        r.GetDecimal(4), r.GetDecimal(5), new(r.GetUInt64(6), r.GetString(7), Sql.Text(r, "supplier_lot"),
            Day(r, "manufactured_on"), Day(r, "expires_on"), r.GetBoolean(11)));
    private static async Task<Bucket> GetBucket(Scope s, ulong id) =>
        await s.One(BucketSelect + " AND k.id=@id", ReadBucket, ("id", id)) ?? throw Missing();

    private static async Task<decimal> Reserved(Scope s, ulong bucket) => Convert.ToDecimal(await s.Scalar("""
        SELECT COALESCE(SUM(reserved_quantity-consumed_quantity-released_quantity),0)
        FROM stock_reservations WHERE tenant_id=@tenant AND company_id=@company AND bucket_id=@bucket
        """, ("bucket", bucket)));

    private static bool Eligible(StockLot lot, DateOnly today) => !lot.Blocked && !(lot.Expiry < today);

    private static async Task<ulong> LocateBucket(Scope s, ulong warehouse, ulong item, StockLot lot, string condition)
    {
        var kind = condition switch { "AVAILABLE" => "STORAGE", "HOLD" => "HOLD", "DAMAGED" => "DAMAGED", "TRANSIT" => "TRANSIT", _ => throw Invalid("Invalid stock condition.") };
        var location = await s.Scalar("""
            SELECT id FROM locations WHERE tenant_id=@tenant AND company_id=@company AND warehouse_id=@warehouse AND kind=@kind
            """, ("warehouse", warehouse), ("kind", kind)) ?? throw Missing();
        var existing = await s.Scalar("""
            SELECT id FROM stock_buckets WHERE tenant_id=@tenant AND company_id=@company AND lot_id=@lot AND location_id=@location AND stock_condition=@condition
            """, ("lot", lot.Id), ("location", location), ("condition", condition));
        if (existing is not null) return Convert.ToUInt64(existing);
        return await s.Insert("""
            INSERT INTO stock_buckets(tenant_id,company_id,warehouse_id,location_id,item_id,lot_id,location_kind,stock_condition)
            VALUES(@tenant,@company,@warehouse,@location,@item,@lot,@kind,@condition)
            """, ("warehouse", warehouse), ("location", location), ("item", item), ("lot", lot.Id), ("kind", kind), ("condition", condition));
    }

    private sealed record ProductionTag(string Role, int? Group);

    private static Task<ulong> MakeLine(Scope s, ulong doc, ulong warehouse, int index, StockUnit unit, StockLot? lot,
        string condition, decimal entered, decimal quantity, decimal value, decimal unitCost = 0, ProductionTag? production = null)
    {
        var columns = production is null ? "" : ",production_role,production_input_group";
        var values = production is null ? "" : ",@role,@group";
        return s.Insert($"""
            INSERT INTO document_lines(tenant_id,company_id,document_id,warehouse_id,item_id,item_unit_id,lot_id,line_number,
              sku,item_name,unit_code,unit_name,lot_code,supplier_lot,manufactured_on,expires_on,stock_condition,entered_quantity,
              conversion_factor,base_quantity,entered_unit_cost,base_unit_cost,carried_value{columns})
            VALUES(@tenant,@company,@doc,@warehouse,@item,@unit,@lot,@index,@sku,@name,@code,@unitName,@batch,@supplier,
              @manufactured,@expiry,@condition,@entered,@factor,@quantity,@unitCost,@unitCost,@value{values})
            """, ("doc", doc), ("warehouse", warehouse), ("item", unit.ItemId), ("unit", unit.Id), ("lot", lot?.Id), ("index", index),
            ("sku", unit.Sku), ("name", unit.ItemName), ("code", unit.Code), ("unitName", unit.Name), ("batch", lot?.Code ?? ""),
            ("supplier", lot?.Supplier), ("manufactured", lot?.Manufactured), ("expiry", lot?.Expiry), ("condition", condition),
            ("entered", entered), ("factor", unit.Factor), ("quantity", quantity), ("value", value), ("unitCost", unitCost),
            ("role", production?.Role), ("group", production?.Group));
    }

    private static async Task<ulong> MoveLine(Scope s, ulong doc, ulong warehouse, int index, ulong bucket, StockUnit unit,
        StockLot lot, string condition, decimal quantity, decimal value, bool issue, decimal? entered = null, decimal unitCost = 0)
    {
        var lineId = await MakeLine(s, doc, warehouse, index, unit, lot, condition, entered ?? quantity, quantity, value, unitCost);
        return await WriteMovement(s, doc, lineId, bucket, warehouse, unit.ItemId, lot.Id, condition,
            issue ? -quantity : quantity, issue ? -value : value);
    }

    private static decimal Carry(decimal quantity, decimal remaining, decimal value)
    {
        try { return ReceiptMath.IssueValue(quantity, remaining, value); }
        catch (ArgumentException e) { throw Conflict(e.Message); }
    }
}

using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using Conex360.Application.Identity;
using Conex360.Application.Inventory;
using Conex360.Domain.Catalog;
using Conex360.Domain.Identity;
using Conex360.Domain.Inventory;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed partial class InventoryStore(Database database, AuthPolicy auth, InventorySettings settings, TimeProvider clock) : IInventoryStore, IStockOperations, IManufacturingStore
{
    private static AppFailure Invalid(string message) => new(400, "INVALID_INVENTORY", message);
    private static AppFailure Missing() => new(404, "NOT_FOUND", "The stock record or warehouse is unavailable.");
    private static AppFailure Conflict(string message) => new(409, "INVENTORY_CONFLICT", message);

    internal static async Task<bool> SchemaInstalledAsync(MySqlConnection c, MySqlTransaction t, CancellationToken ct) =>
        await Sql.Scalar(c, t, "SELECT 1 FROM schema_migrations WHERE version=8", ct) is not null;

    internal static async Task RequireEmptyLocationAsync(MySqlConnection c, MySqlTransaction t, Membership member,
        ulong? warehouse, ulong? branch, CancellationToken ct)
    {
        if (!await SchemaInstalledAsync(c, t, ct)) return;
        var found = await Sql.Scalar(c, t, """
            SELECT 1 FROM stock_balances b JOIN stock_buckets k
              ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
            JOIN warehouses w ON w.tenant_id=k.tenant_id AND w.company_id=k.company_id AND w.id=k.warehouse_id
            WHERE b.tenant_id=@tenant AND b.company_id=@company AND b.on_hand_base>0
              AND (@warehouse IS NULL OR w.id=@warehouse) AND (@branch IS NULL OR w.branch_id=@branch) LIMIT 1
            """, ct, ("tenant", member.TenantId), ("company", member.CompanyId), ("warehouse", warehouse), ("branch", branch));
        if (found is not null) throw Conflict("Move or resolve physical stock before deactivating this location.");
        await RequireNoOpenLocationOperations(c, t, member, warehouse, branch, ct);
    }
    private const string WarehouseAccess = """
         w.tenant_id=@tenant AND w.company_id=@company AND w.kind='ORDINARY'
        AND (@branch IS NULL OR w.branch_id=@branch)
        AND (@admin=1 OR (w.is_active=1 AND EXISTS (
            SELECT 1 FROM membership_branches g JOIN branches b
              ON b.tenant_id=g.tenant_id AND b.company_id=g.company_id AND b.id=g.branch_id
            WHERE g.tenant_id=w.tenant_id AND g.company_id=w.company_id AND g.branch_id=w.branch_id
              AND g.membership_id=@actor AND g.is_active=1 AND b.is_active=1)))
        """;

    private sealed record Scope(MySqlConnection Connection, MySqlTransaction Transaction, SessionData Session,
        DateTimeOffset Now, CancellationToken Ct)
    {
        public Membership Member => Session.Selected!;
        public bool Admin => Member.Role == MembershipRoles.Administrator;
        private (string, object?)[] Args => [("tenant", Member.TenantId), ("company", Member.CompanyId),
            ("actor", Member.Id), ("admin", Admin), ("branch", Session.Session.SelectedBranchId)];

        public Task<object?> Scalar(string sql, params (string, object?)[] values) =>
            Sql.Scalar(Connection, Transaction, sql, Ct, [.. Args, .. values]);
        public Task<int> Execute(string sql, params (string, object?)[] values) =>
            Sql.Execute(Connection, Transaction, sql, Ct, [.. Args, .. values]);
        public Task<T?> One<T>(string sql, Func<MySqlDataReader, T> map, params (string, object?)[] values) where T : class =>
            Sql.One(Connection, Transaction, sql, map, Ct, [.. Args, .. values]);
        public async Task<IReadOnlyList<T>> List<T>(string sql, Func<MySqlDataReader, T> map, params (string, object?)[] values)
        {
            await using var cmd = Sql.Command(Connection, Transaction, sql, [.. Args, .. values]);
            await using var reader = await cmd.ExecuteReaderAsync(Ct);
            var rows = new List<T>();
            while (await reader.ReadAsync(Ct)) rows.Add(map(reader));
            return rows;
        }

        public async Task<ulong> Insert(string sql, params (string, object?)[] values)
        {
            await using var cmd = Sql.Command(Connection, Transaction, sql, [.. Args, .. values]);
            await cmd.ExecuteNonQueryAsync(Ct);
            return checked((ulong)cmd.LastInsertedId);
        }
    }

    private async Task<T> InScope<T>(SessionData session, bool admin, Func<Scope, Task<T>> action, CancellationToken ct)
    {
        if (!settings.Enabled) throw new AppFailure(503, "INVENTORY_DISABLED", "Inventory posting and views are disabled.");
        await using var connection = await database.OpenAsync(ct);
        await using var transaction = await connection.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, ct);
        var current = await IdentityStore.Guard(connection, transaction, session, clock.GetUtcNow(), auth, true, admin, ct);
        var result = await action(new(connection, transaction, current, clock.GetUtcNow(), ct));
        await transaction.CommitAsync(ct);
        return result;
    }

    private sealed record BusinessClock(string Currency, byte MinorUnits, DateOnly Today);
    private static async Task<BusinessClock> Business(Scope s) =>
        await s.One("SELECT currency_code,currency_minor_units,timezone FROM companies WHERE tenant_id=@tenant AND id=@company",
            r => new BusinessClock(r.GetString(0), r.GetByte(1), DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(
                s.Now, TimeZoneInfo.FindSystemTimeZoneById(r.GetString(2))).DateTime))) ?? throw Missing();
    private sealed record Warehouse(ulong Id, ulong Branch, ulong Version, string Name, string Code, bool Active);
    private static Task<Warehouse?> FindWarehouse(Scope s, ulong id) =>
        s.One("""
            SELECT w.id,w.branch_id,w.row_version,w.name,w.code,(w.is_active AND b.is_active) AS active
            FROM warehouses w JOIN branches b ON b.tenant_id=w.tenant_id AND b.company_id=w.company_id AND b.id=w.branch_id
            WHERE w.id=@id AND
            """ + WarehouseAccess, r => new Warehouse(r.GetUInt64(0), r.GetUInt64(1), r.GetUInt64(2),
            r.GetString(3), r.GetString(4), r.GetBoolean(5)), ("id", id));

    public Task<IReadOnlyList<InventoryWarehouse>> WarehousesAsync(SessionData session, CancellationToken ct) =>
        InScope(session, false, s => s.List("SELECT w.id,w.branch_id,w.name,w.row_version FROM warehouses w WHERE " +
            WarehouseAccess + " AND w.is_active=1 AND EXISTS (SELECT 1 FROM branches b WHERE b.tenant_id=w.tenant_id AND b.company_id=w.company_id AND b.id=w.branch_id AND b.is_active=1) ORDER BY w.name,w.id",
            r => new InventoryWarehouse(r.GetUInt64(0), r.GetUInt64(1), r.GetString(2), r.GetUInt64(3))), ct);

    private sealed record Item(ulong Version, ulong UnitVersion, string Sku, string Name, string UnitCode, string UnitName,
        decimal Factor, bool Discrete, bool BaseDiscrete, string Tracking, bool ExpiryRequired);
    private sealed record Lot(ulong Id, string? SupplierLot, DateOnly? Manufactured, DateOnly? Expiry, bool Blocked);
    private sealed record PreparedLine(ReceiptLine Input, Item Item, Lot? ExistingLot, ulong Location, string LocationKind,
        string Code, decimal BaseQuantity, decimal BaseCost, decimal Value);
    private sealed record Prepared(BusinessClock Business, Warehouse Warehouse, string? Supplier, IReadOnlyList<PreparedLine> Lines, decimal Total);

    private static string? Clean(string? value, int max)
    {
        var result = value?.Trim();
        if (result?.Length > max || result?.Any(char.IsControl) == true) throw Invalid("Check reference and notes lengths and characters.");
        return string.IsNullOrEmpty(result) ? null : result;
    }

    private static ReceiptInput Normalize(ReceiptInput input)
    {
        if (input.OperationId == Guid.Empty || input.Lines is null || input.Lines.Count is < 1 or > 100 || input.Lines.Any(x => x is null))
            throw Invalid("Provide an operation ID and between one and 100 stock lines.");
        return input with
        {
            SupplierReference = Clean(input.SupplierReference, 120),
            Notes = Clean(input.Notes, 700),
            Lines = input.Lines.Select(x => x with { LotCode = Clean(x.LotCode, 128), SupplierLot = Clean(x.SupplierLot, 128) }).ToArray()
        };
    }

    private static byte[] Hash(ReceiptInput input)
    {
        static string? Number(decimal? value) => value?.ToString("G29", CultureInfo.InvariantCulture);
        var canonical = new
        {
            Version = 1,
            input.WarehouseId,
            input.WarehouseVersion,
            input.ExpectedCurrency,
            input.BusinessDate,
            input.SupplierId,
            input.SupplierReference,
            input.Notes,
            Lines = input.Lines.Select(x => new
            {
                x.ItemId,
                x.ItemUnitId,
                x.ItemVersion,
                x.UnitVersion,
                Quantity = Number(x.Quantity),
                Cost = Number(x.EnteredUnitCost),
                x.ConfirmZeroCost,
                x.Condition,
                x.LotCode,
                x.SupplierLot,
                x.ManufacturedOn,
                x.ExpiresOn
            })
        };
        return SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(canonical));
    }

    private static DateOnly? Day(MySqlDataReader r, string name) =>
        r[name] is DBNull ? null : DateOnly.FromDateTime(r.GetDateTime(name));

    private static async Task<Prepared> Prepare(Scope s, Warehouse warehouse, bool opening, ReceiptInput input,
        bool adjustment = false, bool completingCount = false)
    {
        if (!completingCount) await RequireUnfrozen(s, warehouse.Id);
        var business = await Business(s);
        if (!string.Equals(business.Currency, input.ExpectedCurrency, StringComparison.Ordinal))
            throw Conflict("The business currency changed. Refresh before confirming costs.");
        if (!warehouse.Active || warehouse.Version != input.WarehouseVersion) throw Conflict("The warehouse changed. Refresh it before posting.");
        if (input.BusinessDate.Year < 1000 || input.BusinessDate > business.Today)
            throw Invalid("Enter a business date on or before the current local date.");

        string? supplier = null;
        if (opening || adjustment)
        {
            if (input.SupplierId is not null || input.SupplierReference is not null) throw Invalid("Opening stock has no supplier.");
        }
        else
        {
            supplier = await s.Scalar("SELECT name FROM parties WHERE tenant_id=@tenant AND company_id=@company AND id=@id AND is_supplier=1 AND is_active=1",
                ("id", input.SupplierId)) as string ?? throw Invalid("Choose an active supplier.");
        }

        var lines = new List<PreparedLine>();
        var checkedOpening = new HashSet<ulong>();
        var identities = new Dictionary<(ulong, string), (string?, DateOnly?, DateOnly?)>();
        decimal total = 0;
        foreach (var line in input.Lines)
        {
            var item = await s.One("""
                SELECT i.row_version,iu.row_version,i.sku,i.name,u.code,u.name,iu.to_base_factor,u.is_discrete,bu.is_discrete,i.tracking_mode,i.expiry_required
                FROM items i JOIN item_units iu ON iu.tenant_id=i.tenant_id AND iu.company_id=i.company_id AND iu.item_id=i.id
                JOIN units u ON u.tenant_id=iu.tenant_id AND u.company_id=iu.company_id AND u.id=iu.unit_id
                JOIN units bu ON bu.tenant_id=i.tenant_id AND bu.company_id=i.company_id AND bu.id=i.base_unit_id
                WHERE i.tenant_id=@tenant AND i.company_id=@company AND i.id=@item AND iu.id=@unit
                  AND i.is_active=1 AND iu.is_active=1 AND u.is_active=1 AND bu.is_active=1 AND (@opening=1 OR i.purchase_enabled=1)
                """, r => new Item(r.GetUInt64(0), r.GetUInt64(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetString(5),
                r.GetDecimal(6), r.GetBoolean(7), r.GetBoolean(8), r.GetString(9), r.GetBoolean(10)),
                ("item", line.ItemId), ("unit", line.ItemUnitId), ("opening", opening || adjustment)) ?? throw Invalid("Select an active product and configured unit allowed for this document.");
            if (item.Version != line.ItemVersion || item.UnitVersion != line.UnitVersion)
                throw Conflict("A selected product or unit changed. Refresh it before posting.");

            if (opening && checkedOpening.Add(line.ItemId) && await s.Scalar("""
                SELECT 1 FROM stock_entries WHERE tenant_id=@tenant AND company_id=@company AND warehouse_id=@warehouse AND item_id=@item LIMIT 1
                """, ("warehouse", warehouse.Id), ("item", line.ItemId)) is not null)
                throw Conflict("Opening stock is allowed only before the first movement for this product and warehouse.");

            if (line.EnteredUnitCost is not { } cost || (cost == 0 && !line.ConfirmZeroCost))
                throw Invalid("Enter the actual cost per selected unit and explicitly confirm any zero cost.");
            (decimal baseQuantity, decimal baseCost, decimal value) amounts;
            try { amounts = ReceiptMath.Calculate(line.Quantity, item.Factor, cost, item.Discrete, item.BaseDiscrete); }
            catch (ArgumentException e) { throw Invalid(e.Message); }
            total += amounts.value;
            if (!CatalogNumbers.Fits(total, 6)) throw Invalid("Document value exceeds supported precision.");

            var code = line.LotCode;
            if (item.Tracking == "NONE")
            {
                if (code is not null || line.SupplierLot is not null || line.ManufacturedOn is not null || line.ExpiresOn is not null)
                    throw Invalid("Untracked products use the system lot without dates.");
                code = "SYSTEM";
            }
            else if (code is null || code.Equals("SYSTEM", StringComparison.OrdinalIgnoreCase) || item.ExpiryRequired && line.ExpiresOn is null)
                throw Invalid("Enter an identifiable lot code and the required expiry date.");

            if (line.ManufacturedOn is { Year: < 1000 } || line.ExpiresOn is { Year: < 1000 } ||
                line.ManufacturedOn > input.BusinessDate || line.ManufacturedOn > line.ExpiresOn)
                throw Invalid("Manufacturing date must not be later than receipt or expiry.");

            var lot = await s.One("""
                SELECT * FROM lots WHERE tenant_id=@tenant AND company_id=@company AND item_id=@item AND lot_code=@code
                """, r => new Lot(r.GetUInt64("id"), Sql.Text(r, "supplier_lot"), Day(r, "manufactured_on"),
                Day(r, "expires_on"), r.GetBoolean("is_blocked")), ("item", line.ItemId), ("code", code));
            var metadata = (line.SupplierLot, line.ManufacturedOn, line.ExpiresOn);
            var identity = (line.ItemId, code);
            if ((lot is not null && metadata != (lot.SupplierLot, lot.Manufactured, lot.Expiry)) ||
                (identities.TryGetValue(identity, out var earlier) && earlier != metadata))
                throw Conflict("A reused lot must match the recorded supplier lot and dates.");
            identities[identity] = metadata;

            var locationKind = line.Condition switch
            {
                "AVAILABLE" when line.ExpiresOn < business.Today || lot?.Blocked == true =>
                    throw Invalid("Expired or blocked stock must be held or damaged."),
                "AVAILABLE" => "STORAGE",
                "HOLD" => "HOLD",
                "DAMAGED" => "DAMAGED",
                _ => throw Invalid("Select an accepted, held or damaged disposition.")
            };
            var location = await s.Scalar("""
                SELECT id FROM locations WHERE tenant_id=@tenant AND company_id=@company AND warehouse_id=@warehouse AND kind=@kind
                """, ("warehouse", warehouse.Id), ("kind", locationKind)) ?? throw Missing();
            lines.Add(new(line, item, lot, Convert.ToUInt64(location), locationKind, code,
                amounts.baseQuantity, amounts.baseCost, amounts.value));
        }
        return new(business, warehouse, supplier, lines, total);
    }

    public Task<ReceiptPreview> PreviewAsync(SessionData session, bool opening, ReceiptInput input, CancellationToken ct) =>
        InScope(session, opening, async s =>
        {
            input = Normalize(input);
            var prepared = await Prepare(s, await FindWarehouse(s, input.WarehouseId) ?? throw Missing(), opening, input);
            return new ReceiptPreview(prepared.Lines.Select(x => new ReceiptPreviewLine(x.Item.Sku, x.Item.Name, x.BaseQuantity, x.BaseCost, x.Value)).ToArray(),
                decimal.Round(prepared.Total, prepared.Business.MinorUnits, MidpointRounding.AwayFromZero), prepared.Business.Currency);
        }, ct);

    public Task<PostedReceipt> PostAsync(SessionData session, bool opening, ReceiptInput input, string correlation, CancellationToken ct) =>
        InScope(session, opening, async s =>
        {
            input = Normalize(input);
            var warehouse = await FindWarehouse(s, input.WarehouseId) ?? throw Missing();
            var command = opening ? "OPEN" : "GRN";
            var hash = Hash(input);
            var replay = await s.One("""
                SELECT k.request_hash,d.id,d.document_number FROM idempotency_keys k JOIN documents d
                  ON d.tenant_id=k.tenant_id AND d.company_id=k.company_id AND d.id=k.document_id
                WHERE k.tenant_id=@tenant AND k.company_id=@company AND k.actor_membership_id=@actor AND k.command=@command AND k.operation_key=@key
                """, r => new { Hash = (byte[])r[0], Result = new PostedReceipt(r.GetUInt64(1), r.GetString(2)) },
                ("command", command), ("key", input.OperationId));
            if (replay is not null)
            {
                if (!CryptographicOperations.FixedTimeEquals(replay.Hash, hash)) throw Conflict("The operation ID was already used with different input.");
                return replay.Result;
            }

            var prepared = await Prepare(s, warehouse, opening, input);
            var number = await NextNumber(s, command, input.BusinessDate.Year);
            var id = await s.Insert("""
                INSERT INTO documents(tenant_id,company_id,document_type,document_number,warehouse_id,actor_membership_id,warehouse_name,warehouse_code,
                    business_date,posted_at,currency_code,currency_minor_units,notes,operational_total)
                VALUES(@tenant,@company,@command,@number,@warehouse,@actor,@name,@code,@date,@now,@currency,@minor,@notes,@total)
                """, ("command", command), ("number", number), ("warehouse", warehouse.Id), ("name", warehouse.Name), ("code", warehouse.Code),
                ("date", input.BusinessDate), ("now", s.Now), ("currency", prepared.Business.Currency), ("minor", prepared.Business.MinorUnits),
                ("notes", input.Notes), ("total", prepared.Total));
            if (!opening)
                await s.Execute("""
                    INSERT INTO goods_receipts(tenant_id,company_id,document_id,supplier_id,supplier_name,supplier_reference)
                    VALUES(@tenant,@company,@doc,@supplier,@name,@reference)
                    """, ("doc", id), ("supplier", input.SupplierId), ("name", prepared.Supplier), ("reference", input.SupplierReference));

            var ordered = prepared.Lines.Select((line, index) => (Line: line, Number: index + 1))
                .OrderBy(x => x.Line.Input.ItemId).ThenBy(x => x.Line.Code, StringComparer.Ordinal).ThenBy(x => x.Line.Location);
            foreach (var row in ordered) await Append(s, id, warehouse.Id, row.Number, row.Line);

            await s.Execute("""
                UPDATE companies SET currency_locked_at=@now,updated_at=@now,row_version=row_version+1
                WHERE tenant_id=@tenant AND id=@company AND currency_locked_at IS NULL
                """, ("now", s.Now));
            await IdentityStore.Audit(s.Connection, s.Transaction, s.Member, opening ? "OPENING_POSTED" : "RECEIPT_POSTED", "DOCUMENT",
                id, "Inventory posted", s.Now, correlation, ct, detailsJson: JsonSerializer.Serialize(new
                {
                    outletId = warehouse.Branch.ToString(CultureInfo.InvariantCulture),
                    warehouseId = warehouse.Id.ToString(CultureInfo.InvariantCulture),
                    zeroCostLines = prepared.Lines.Count(x => x.Input.EnteredUnitCost == 0)
                }));
            await s.Execute("""
                INSERT INTO idempotency_keys(tenant_id,company_id,actor_membership_id,document_id,command,operation_key,request_hash)
                VALUES(@tenant,@company,@actor,@doc,@command,@key,@hash)
                """, ("doc", id), ("command", command), ("key", input.OperationId), ("hash", hash));
            return new PostedReceipt(id, number);
        }, ct);

    private static async Task<string> NextNumber(Scope s, string command, int year)
    {
        await s.Execute("""
            INSERT INTO document_sequences(tenant_id,company_id,document_type,series,next_value)
            VALUES(@tenant,@company,@type,@year,1) ON DUPLICATE KEY UPDATE next_value=next_value
            """, ("type", command), ("year", year));
        var next = Convert.ToUInt64(await s.Scalar("""
            SELECT next_value FROM document_sequences WHERE tenant_id=@tenant AND company_id=@company AND document_type=@type AND series=@year FOR UPDATE
            """, ("type", command), ("year", year)));
        await s.Execute("""
            UPDATE document_sequences SET next_value=next_value+1 WHERE tenant_id=@tenant AND company_id=@company AND document_type=@type AND series=@year
            """, ("type", command), ("year", year));
        return FormattableString.Invariant($"{command}-{year:D4}-{next:D6}");
    }

    private static async Task<(ulong Bucket, ulong Entry, ulong Lot)> Append(Scope s, ulong document, ulong warehouse, int lineNumber, PreparedLine line)
    {
        var input = line.Input;
        var existingId = line.ExistingLot?.Id;
        if (existingId is null)
        {
            var found = await s.Scalar("SELECT id FROM lots WHERE tenant_id=@tenant AND company_id=@company AND item_id=@item AND lot_code=@lot",
                ("item", input.ItemId), ("lot", line.Code));
            existingId = found is null ? null : Convert.ToUInt64(found);
        }
        var lot = existingId ?? await s.Insert("""
            INSERT INTO lots(tenant_id,company_id,item_id,lot_code,tracking_mode,supplier_lot,manufactured_on,expires_on)
            VALUES(@tenant,@company,@item,@lot,@tracking,@supplierLot,@manufactured,@expiry)
            """, ("item", input.ItemId), ("lot", line.Code), ("tracking", line.Item.Tracking), ("supplierLot", input.SupplierLot),
            ("manufactured", input.ManufacturedOn), ("expiry", input.ExpiresOn));

        (string, object?)[] identity = [("warehouse", warehouse), ("item", input.ItemId), ("lot", lot), ("condition", input.Condition)];
        var bucketId = await s.Scalar("""
            SELECT id FROM stock_buckets WHERE tenant_id=@tenant AND company_id=@company AND lot_id=@lot AND location_id=@location AND stock_condition=@condition
            """, [.. identity, ("location", line.Location)]);
        var bucket = bucketId is not null ? Convert.ToUInt64(bucketId) : await s.Insert("""
            INSERT INTO stock_buckets(tenant_id,company_id,warehouse_id,location_id,item_id,lot_id,location_kind,stock_condition)
            VALUES(@tenant,@company,@warehouse,@location,@item,@lot,@locationKind,@condition)
            """, [.. identity, ("location", line.Location), ("locationKind", line.LocationKind)]);

        var lineId = await s.Insert("""
            INSERT INTO document_lines(tenant_id,company_id,document_id,warehouse_id,item_id,item_unit_id,lot_id,line_number,sku,item_name,
                unit_code,unit_name,lot_code,supplier_lot,manufactured_on,expires_on,stock_condition,entered_quantity,conversion_factor,
                base_quantity,entered_unit_cost,base_unit_cost,carried_value)
            VALUES(@tenant,@company,@doc,@warehouse,@item,@unit,@lot,@line,@sku,@name,@unitCode,@unitName,@lotCode,@supplierLot,
                @manufactured,@expiry,@condition,@entered,@factor,@quantity,@cost,@baseCost,@value)
            """, [.. identity, ("doc", document), ("unit", input.ItemUnitId), ("line", lineNumber), ("sku", line.Item.Sku),
                ("name", line.Item.Name), ("unitCode", line.Item.UnitCode), ("unitName", line.Item.UnitName), ("lotCode", line.Code),
                ("supplierLot", input.SupplierLot), ("manufactured", input.ManufacturedOn), ("expiry", input.ExpiresOn), ("entered", input.Quantity),
                ("factor", line.Item.Factor), ("quantity", line.BaseQuantity), ("cost", input.EnteredUnitCost), ("baseCost", line.BaseCost), ("value", line.Value)]);

        var entry = await WriteMovement(s, document, lineId, bucket, warehouse, input.ItemId, lot, input.Condition, line.BaseQuantity, line.Value);
        return (bucket, entry, lot);
    }

    private static async Task<ulong> WriteMovement(Scope s, ulong document, ulong lineId, ulong bucket,
        ulong warehouse, ulong item, ulong lot, string condition, decimal quantity, decimal value)
    {
        var existing = await s.One("""
            SELECT on_hand_base,operational_value FROM stock_balances
              WHERE tenant_id=@tenant AND company_id=@company AND bucket_id=@bucket FOR UPDATE
            """, r => new { Quantity = r.GetDecimal(0), Value = r.GetDecimal(1) }, ("bucket", bucket));
        var nextQuantity = (existing?.Quantity ?? 0) + quantity;
        var nextValue = (existing?.Value ?? 0) + value;
        if (!CatalogNumbers.Fits(nextQuantity, 9) || !CatalogNumbers.Fits(nextValue, 6) ||
            (nextQuantity == 0 && nextValue != 0))
            throw Conflict("The resulting stock quantity or value is invalid.");

        var entry = await s.Insert("""
            INSERT INTO stock_entries(tenant_id,company_id,document_id,line_id,bucket_id,warehouse_id,item_id,lot_id,stock_condition,quantity_base,value_delta)
            VALUES(@tenant,@company,@doc,@line,@bucket,@warehouse,@item,@lot,@condition,@quantity,@value)
            """, ("warehouse", warehouse), ("item", item), ("lot", lot), ("condition", condition),
            ("doc", document), ("line", lineId), ("bucket", bucket), ("quantity", quantity), ("value", value));
        await s.Execute("""
            INSERT INTO stock_balances(tenant_id,company_id,bucket_id,last_entry_id,row_version,on_hand_base,operational_value)
            VALUES(@tenant,@company,@bucket,@entry,1,@quantity,@value)
            ON DUPLICATE KEY UPDATE last_entry_id=@entry,row_version=row_version+1,on_hand_base=@quantity,operational_value=@value
            """, ("bucket", bucket), ("entry", entry), ("quantity", nextQuantity), ("value", nextValue));
        return entry;
    }
}

using System.Text.Json;
using System.Text.Json.Serialization;
using Conex360.Application.Catalog;
using Conex360.Application.Identity;
using Conex360.Domain.Catalog;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed class CatalogStore(Database database, AuthPolicy auth, CatalogSettings settings, TimeProvider clock) : ICatalogStore
{
    private static AppFailure Invalid(string text) => new(400, "INVALID_CATALOG", text);
    private static AppFailure Missing() => new(404, "NOT_FOUND", "The requested catalogue record is unavailable.");
    private static AppFailure Conflict() => new(409, "VERSION_CONFLICT", "The record changed. Refresh and try again.");
    private static bool Admin(SessionData s) => s.Selected!.Role == MembershipRoles.Administrator;
    private static (string, object?)[] Scope(SessionData s) => [("tenant", s.Selected!.TenantId), ("company", s.Selected.CompanyId)];
    private static void Text(string? value, int max, string label, bool required = false) { if (required && string.IsNullOrWhiteSpace(value) || value?.Length > max) throw Invalid($"Check {label} (maximum {max} characters)."); }
    private static string Code(string? value, int max) { Text(value, max, "code", true); var code = value!.Trim().ToUpperInvariant(); if (!code.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.' or '/')) throw Invalid("Codes support letters, digits, dots, hyphens, underscores and slashes."); return code; }
    private async Task<T> Scoped<T>(SessionData observed, bool admin, Func<MySqlConnection, MySqlTransaction, SessionData, DateTimeOffset, Task<T>> action, CancellationToken ct)
    {
        if (!settings.Enabled) throw new AppFailure(503, "CATALOG_UNAVAILABLE", "Catalogue management has not been enabled.");
        await using var c = await database.OpenAsync(ct); await using var t = await c.BeginTransactionAsync(ct); var now = clock.GetUtcNow();
        var current = await IdentityStore.Guard(c, t, observed, now, auth, true, admin, ct);
        try { var result = await action(c, t, current, now); await t.CommitAsync(ct); return result; }
        catch (MySqlException e) when (e.Number == 1062) { throw new AppFailure(409, "DUPLICATE_CATALOG_CODE", "The code, SKU, unit or barcode is already reserved in this company."); }
    }
    private static async Task<List<T>> List<T>(MySqlConnection c, MySqlTransaction t, string sql, Func<MySqlDataReader, T> map, CancellationToken ct, params (string, object?)[] args) { await using var cmd = Sql.Command(c, t, sql, args); await using var r = await cmd.ExecuteReaderAsync(ct); var list = new List<T>(); while (await r.ReadAsync(ct)) list.Add(map(r)); return list; }
    private static Task<int> Audit(MySqlConnection c, MySqlTransaction t, SessionData s, string action, string entity, ulong id, string reason, DateTimeOffset now, string correlation, CancellationToken ct) => IdentityStore.Audit(c, t, s.Selected!, action, entity, id, reason, now, correlation, ct);
    private static void Version(ulong current, ulong expected) { if (current != expected) throw Conflict(); }
    private static Unit UnitRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetString("code"), r.GetString("name"), r.GetString("dimension"), r.GetBoolean("is_discrete"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static Category CategoryRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetString("code"), r.GetString("name"), Sql.Text(r, "description"), r["parent_id"] is DBNull ? null : r.GetUInt64("parent_id"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static Product ProductRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetString("sku"), r.GetString("name"), Sql.Text(r, "description"), r["category_id"] is DBNull ? null : r.GetUInt64("category_id"), r.GetUInt64("base_unit_id"), r.GetString("kind"), r.GetBoolean("purchase_enabled"), r.GetBoolean("sale_enabled"), r.GetBoolean("manufacture_enabled"), r.GetString("tracking_mode"), r.GetBoolean("expiry_required"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static ItemUnit ItemUnitRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetUInt64("unit_id"), r.GetDecimal("to_base_factor"), r["purchase_price"] is DBNull ? null : r.GetDecimal("purchase_price"), r["selling_price"] is DBNull ? null : r.GetDecimal("selling_price"), r.GetBoolean("is_purchase_default"), r.GetBoolean("is_sale_default"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static Barcode BarcodeRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetUInt64("item_unit_id"), r.GetString("barcode"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static Supplier SupplierRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetString("code"), r.GetString("name"), Sql.Text(r, "phone"), Sql.Text(r, "email"), Sql.Text(r, "address"), Sql.Text(r, "contact_person"), Sql.Text(r, "notes"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static Task<List<Unit>> Units(MySqlConnection c, MySqlTransaction t, SessionData s, CancellationToken ct) => List(c, t, "SELECT * FROM units WHERE tenant_id=@tenant AND company_id=@company AND (@admin=1 OR is_active=1) ORDER BY name,id", UnitRow, ct, [.. Scope(s), ("admin", Admin(s))]);
    private static Task<List<Category>> Categories(MySqlConnection c, MySqlTransaction t, SessionData s, CancellationToken ct) => List(c, t, "SELECT * FROM item_categories WHERE tenant_id=@tenant AND company_id=@company AND (@admin=1 OR is_active=1) ORDER BY name,id", CategoryRow, ct, [.. Scope(s), ("admin", Admin(s))]);
    public Task<IReadOnlyList<Unit>> UnitsAsync(SessionData s, CancellationToken ct) => Scoped<IReadOnlyList<Unit>>(s, false, async (c, t, current, now) => await Units(c, t, current, ct), ct);
    public Task<Unit> SaveUnitAsync(SessionData s, ulong? id, UnitEdit e, string correlation, CancellationToken ct)
    {
        var code = Code(e.Code, 20); Text(e.Name, 100, "unit name", true); Text(e.Reason, 300, "reason", true); if (e.Dimension is not ("COUNT" or "MASS" or "VOLUME" or "OTHER")) throw Invalid("Select a supported measurement dimension.");
        return Scoped(s, true, async (c, t, current, now) =>
        {
            if (id is null) { await Sql.Execute(c, t, "INSERT INTO units(tenant_id,company_id,code,name,dimension,is_discrete,is_active,created_at,updated_at) VALUES(@tenant,@company,@code,@name,@dimension,@discrete,@active,@now,@now)", ct, [.. Scope(current), ("code", code), ("name", e.Name.Trim()), ("dimension", e.Dimension), ("discrete", e.IsDiscrete), ("active", e.IsActive), ("now", now)]); id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)); }
            else
            {
                var old = (await Units(c, t, current, ct)).SingleOrDefault(u => u.Id == id) ?? throw Missing(); Version(old.Version, e.ExpectedVersion);
                var references = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT COUNT(*) FROM item_units WHERE tenant_id=@tenant AND company_id=@company AND unit_id=@id", ct, [.. Scope(current), ("id", id)]));
                if (references > 0 && (old.Dimension != e.Dimension || old.IsDiscrete != e.IsDiscrete)) throw Invalid("Referenced unit dimensions and whole-number semantics cannot change.");
                if (!e.IsActive && Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT COUNT(*) FROM item_units iu JOIN items i ON i.tenant_id=iu.tenant_id AND i.company_id=iu.company_id AND i.id=iu.item_id WHERE iu.tenant_id=@tenant AND iu.company_id=@company AND iu.unit_id=@id AND iu.is_active=1 AND i.is_active=1", ct, [.. Scope(current), ("id", id)])) > 0) throw Invalid("Deactivate or reconfigure dependent active products first.");
                await Sql.Execute(c, t, "UPDATE units SET code=@code,name=@name,dimension=@dimension,is_discrete=@discrete,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("id", id), ("code", code), ("name", e.Name.Trim()), ("dimension", e.Dimension), ("discrete", e.IsDiscrete), ("active", e.IsActive), ("now", now)]);
            }
            await Audit(c, t, current, "UNIT_SAVED", "UNIT", id.Value, e.Reason, now, correlation, ct); return (await Units(c, t, current, ct)).Single(u => u.Id == id);
        }, ct);
    }
    public Task InitializeUnitsAsync(SessionData s, string correlation, CancellationToken ct) => Scoped(s, true, async (c, t, current, now) =>
    {
        var existing = await Units(c, t, current, ct);
        foreach (var entry in new[] { ("EA", "Piece", "COUNT", true), ("BOTTLE", "Bottle", "COUNT", true), ("PACKET", "Packet", "COUNT", true), ("BOX", "Box", "COUNT", true), ("CARTON", "Carton", "COUNT", true), ("KG", "Kilogram", "MASS", false), ("G", "Gram", "MASS", false), ("L", "Litre", "VOLUME", false), ("ML", "Millilitre", "VOLUME", false) })
        {
            if (existing.Any(u => u.Code == entry.Item1)) continue;
            await Sql.Execute(c, t, "INSERT INTO units(tenant_id,company_id,code,name,dimension,is_discrete,created_at,updated_at) VALUES(@tenant,@company,@code,@name,@dimension,@discrete,@now,@now)", ct, [.. Scope(current), ("code", entry.Item1), ("name", entry.Item2), ("dimension", entry.Item3), ("discrete", entry.Item4), ("now", now)]);
            await Audit(c, t, current, "UNIT_INITIALIZED", "UNIT", Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)), "Optional standard units initialized", now, correlation, ct);
        }
        return true;
    }, ct);
    public Task<IReadOnlyList<Category>> CategoriesAsync(SessionData s, CancellationToken ct) => Scoped<IReadOnlyList<Category>>(s, false, async (c, t, current, now) => await Categories(c, t, current, ct), ct);
    public Task<Category> SaveCategoryAsync(SessionData s, ulong? id, CategoryEdit e, string correlation, CancellationToken ct)
    {
        var code = Code(e.Code, 60); Text(e.Name, 150, "category name", true); Text(e.Description, 500, "description"); Text(e.Reason, 300, "reason", true);
        return Scoped(s, true, async (c, t, current, now) =>
        {
            var all = await Categories(c, t, current, ct); if (id is not null) { var old = all.SingleOrDefault(x => x.Id == id) ?? throw Missing(); Version(old.Version, e.ExpectedVersion); }
            var cursor = e.ParentId; var visited = new HashSet<ulong>();
            while (cursor is { } parent) { if (parent == id || !visited.Add(parent)) throw Invalid("Category relationships cannot contain a cycle."); var node = all.SingleOrDefault(x => x.Id == parent) ?? throw Missing(); if (e.IsActive && !node.IsActive) throw Invalid("An active category needs active ancestors."); cursor = node.ParentId; }
            if (!e.IsActive && id is not null && (all.Any(x => x.ParentId == id && x.IsActive) || Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT COUNT(*) FROM items WHERE tenant_id=@tenant AND company_id=@company AND category_id=@id AND is_active=1", ct, [.. Scope(current), ("id", id)])) > 0)) throw Invalid("Deactivate dependent categories and products first.");
            if (id is null) { await Sql.Execute(c, t, "INSERT INTO item_categories(tenant_id,company_id,code,name,description,parent_id,is_active,created_at,updated_at) VALUES(@tenant,@company,@code,@name,@description,@parent,@active,@now,@now)", ct, [.. Scope(current), ("code", code), ("name", e.Name.Trim()), ("description", e.Description), ("parent", e.ParentId), ("active", e.IsActive), ("now", now)]); id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)); }
            else await Sql.Execute(c, t, "UPDATE item_categories SET code=@code,name=@name,description=@description,parent_id=@parent,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("id", id), ("code", code), ("name", e.Name.Trim()), ("description", e.Description), ("parent", e.ParentId), ("active", e.IsActive), ("now", now)]);
            await Audit(c, t, current, "CATEGORY_SAVED", "CATEGORY", id.Value, e.Reason, now, correlation, ct); return (await Categories(c, t, current, ct)).Single(x => x.Id == id);
        }, ct);
    }
    public Task<IReadOnlyList<Product>> ProductsAsync(SessionData s, CancellationToken ct) => Scoped<IReadOnlyList<Product>>(s, false, async (c, t, current, now) => await List(c, t, "SELECT * FROM items WHERE tenant_id=@tenant AND company_id=@company AND (@admin=1 OR is_active=1) ORDER BY name,id LIMIT 1000", ProductRow, ct, [.. Scope(current), ("admin", Admin(current))]), ct);
    private static async Task<ProductDetail> Detail(MySqlConnection c, MySqlTransaction t, SessionData s, ulong id, CancellationToken ct)
    {
        var p = await Sql.One(c, t, "SELECT * FROM items WHERE tenant_id=@tenant AND company_id=@company AND id=@id AND (@admin=1 OR is_active=1)", ProductRow, ct, [.. Scope(s), ("id", id), ("admin", Admin(s))]) ?? throw Missing();
        var units = await List(c, t, "SELECT * FROM item_units WHERE tenant_id=@tenant AND company_id=@company AND item_id=@id AND (@admin=1 OR is_active=1) ORDER BY id", ItemUnitRow, ct, [.. Scope(s), ("id", id), ("admin", Admin(s))]);
        var barcodes = await List(c, t, "SELECT * FROM item_barcodes WHERE tenant_id=@tenant AND company_id=@company AND item_id=@id AND (@admin=1 OR is_active=1) ORDER BY id", BarcodeRow, ct, [.. Scope(s), ("id", id), ("admin", Admin(s))]);
        return new(p, Admin(s) ? units : units.Select(u => u with { PurchasePrice = null }).ToList(), barcodes, Convert.ToString(await Sql.Scalar(c, t, "SELECT currency_code FROM companies WHERE tenant_id=@tenant AND id=@company", ct, Scope(s)))!, Admin(s));
    }
    public Task<ProductDetail> ProductAsync(SessionData s, ulong id, CancellationToken ct) => Scoped(s, false, (c, t, current, now) => Detail(c, t, current, id, ct), ct);
    public Task<ProductDetail> SaveProductAsync(SessionData s, ulong? id, ProductEdit e, string correlation, CancellationToken ct)
    {
        var sku = Code(e.Sku, 60); Text(e.Name, 200, "product name", true); Text(e.Description, 700, "description"); Text(e.Reason, 300, "reason", true);
        if (e.Kind is not ("RAW" or "PACKAGING" or "INTERMEDIATE" or "FINISHED") || e.TrackingMode is not ("NONE" or "LOT") || e.ExpiryRequired && e.TrackingMode != "LOT") throw Invalid("Check product type and lot/expiry settings.");
        if (e.Units is null || e.Units.Count is < 1 or > 100 || e.Units.Select(u => u.UnitId).Distinct().Count() != e.Units.Count) throw Invalid("Configure one unambiguous set of product units.");
        return Scoped(s, true, async (c, t, current, now) =>
        {
            var masters = await Units(c, t, current, ct); var baseUnit = masters.SingleOrDefault(u => u.Id == e.BaseUnitId) ?? throw Missing();
            var old = id is null ? null : await Detail(c, t, current, id.Value, ct);
            if (old is not null && await InventoryStore.SchemaInstalledAsync(c, t, ct))
            {
                var used = await List(c, t, "SELECT DISTINCT item_unit_id FROM document_lines WHERE tenant_id=@tenant AND company_id=@company AND item_id=@item",
                    r => r.GetUInt64(0), ct, [.. Scope(current), ("item", id)]);
                if (used.Count > 0 && (old.Product.TrackingMode != e.TrackingMode || old.Product.ExpiryRequired != e.ExpiryRequired))
                    throw Invalid("Tracking and expiry rules cannot change after stock is posted.");
                if (e.Units.Any(u => u.Id is { } unit && used.Contains(unit) &&
                    old.Units.Any(x => x.Id == unit && x.ToBaseFactor != u.ToBaseFactor)))
                    throw Invalid("A posted unit's conversion factor cannot change.");
                if (!e.IsActive && await Sql.Scalar(c, t, """
                    SELECT 1 FROM stock_buckets k JOIN stock_balances b
                      ON b.tenant_id=k.tenant_id AND b.company_id=k.company_id AND b.bucket_id=k.id
                    WHERE k.tenant_id=@tenant AND k.company_id=@company AND k.item_id=@item AND b.on_hand_base>0 LIMIT 1
                    """, ct, [.. Scope(current), ("item", id)]) is not null)
                    throw Invalid("This product still has physical stock.");
                if (!e.IsActive) await InventoryStore.RequireNoOpenItemRequests(c, t, current.Selected!, id!.Value, ct);
            }
            if (old is not null) { Version(old.Product.Version, e.ExpectedVersion); if (old.Product.BaseUnitId != e.BaseUnitId) throw Invalid("The base unit is immutable; create a new SKU for a different stock identity."); }
            if (e.CategoryId is { } cat) { var category = (await Categories(c, t, current, ct)).SingleOrDefault(x => x.Id == cat) ?? throw Missing(); if (e.IsActive && !category.IsActive) throw Invalid("Select an active category."); }
            if (!e.Units.Any(u => u.UnitId == e.BaseUnitId && u.IsActive && u.ToBaseFactor == 1)) throw Invalid("Configure an active base unit with conversion factor one.");
            if (e.Units.Count(u => u.IsActive && u.IsPurchaseDefault) != (e.PurchaseEnabled ? 1 : 0) || e.Units.Count(u => u.IsActive && u.IsSaleDefault) != (e.SaleEnabled ? 1 : 0)) throw Invalid("Each enabled purchase/sale operation requires exactly one active default unit; disabled operations have none.");
            var barcodeValues = new HashSet<string>(StringComparer.Ordinal); var barcodeIds = new HashSet<ulong>(); var childIds = new HashSet<ulong>();
            foreach (var u in e.Units)
            {
                var master = masters.SingleOrDefault(x => x.Id == u.UnitId) ?? throw Missing();
                if (e.IsActive && u.IsActive && !master.IsActive || !u.IsActive && (u.IsPurchaseDefault || u.IsSaleDefault) || u.ToBaseFactor <= 0 || !CatalogNumbers.Fits(u.ToBaseFactor, 9) || u.UnitId == e.BaseUnitId && u.ToBaseFactor != 1) throw Invalid("Check active units, defaults and exact positive conversion factors.");
                if (master.Dimension != baseUnit.Dimension && master.Dimension != "COUNT") throw Invalid("Direct mass/volume or unrelated-dimension conversion is not supported; configure explicit count packaging for the same product.");
                if (baseUnit.IsDiscrete && (!master.IsDiscrete || u.ToBaseFactor != decimal.Truncate(u.ToBaseFactor))) throw Invalid("Discrete base units require whole-number package quantities.");
                foreach (var price in new[] { u.PurchasePrice, u.SellingPrice }) if (price is { } value && !CatalogNumbers.Fits(value, 6)) throw Invalid("Prices must be nonnegative DECIMAL(24,6) values; leave unset prices blank.");
                if (u.Id is { } uid) { var previous = old?.Units.SingleOrDefault(x => x.Id == uid) ?? throw Missing(); Version(previous.Version, u.ExpectedVersion); if (previous.UnitId != u.UnitId || !childIds.Add(uid)) throw Invalid("Product-unit identity cannot be reassigned."); }
                else if (old?.Units.Any(x => x.UnitId == u.UnitId) == true) throw Invalid("Retain the existing product-unit identity and version.");
                if (u.Barcodes is null || u.Barcodes.Count > 100) throw Invalid("Check the barcode configuration.");
                foreach (var b in u.Barcodes) { ValidateBarcode(b.Value); if (!barcodeValues.Add(b.Value) || b.IsActive && !u.IsActive) throw Invalid("Barcodes must be unambiguous and active mappings need active units."); if (b.Id is { } bid) { var previous = old?.Barcodes.SingleOrDefault(x => x.Id == bid) ?? throw Missing(); Version(previous.Version, b.ExpectedVersion); if (!barcodeIds.Add(bid)) throw Invalid("Duplicate barcode identity."); } }
            }
            if (old is not null && (old.Units.Any(x => !childIds.Contains(x.Id)) || old.Barcodes.Any(x => !barcodeIds.Contains(x.Id)))) throw Invalid("Retain existing units and barcodes; deactivate them instead of deleting history.");
            var fields = new (string, object?)[] { ("sku", sku), ("name", e.Name.Trim()), ("description", e.Description), ("category", e.CategoryId), ("base", e.BaseUnitId), ("kind", e.Kind), ("purchase", e.PurchaseEnabled), ("sale", e.SaleEnabled), ("manufacture", e.ManufactureEnabled), ("tracking", e.TrackingMode), ("expiry", e.ExpiryRequired), ("active", e.IsActive), ("now", now) };
            if (id is null) { await Sql.Execute(c, t, "INSERT INTO items(tenant_id,company_id,sku,name,description,category_id,base_unit_id,kind,purchase_enabled,sale_enabled,manufacture_enabled,tracking_mode,expiry_required,is_active,created_at,updated_at) VALUES(@tenant,@company,@sku,@name,@description,@category,@base,@kind,@purchase,@sale,@manufacture,@tracking,@expiry,@active,@now,@now)", ct, [.. Scope(current), .. fields]); id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)); }
            else await Sql.Execute(c, t, "UPDATE items SET sku=@sku,name=@name,description=@description,category_id=@category,kind=@kind,purchase_enabled=@purchase,sale_enabled=@sale,manufacture_enabled=@manufacture,tracking_mode=@tracking,expiry_required=@expiry,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), .. fields, ("id", id)]);
            // Clear unique default slots before assigning replacements within this same transaction.
            await Sql.Execute(c, t, "UPDATE item_units SET is_purchase_default=0,is_sale_default=0 WHERE tenant_id=@tenant AND company_id=@company AND item_id=@id", ct, [.. Scope(current), ("id", id)]);
            foreach (var u in e.Units)
            {
                var values = new (string, object?)[] { ("item", id), ("unit", u.UnitId), ("base", e.BaseUnitId), ("factor", u.ToBaseFactor), ("purchase", u.PurchasePrice), ("selling", u.SellingPrice), ("pd", u.IsPurchaseDefault), ("sd", u.IsSaleDefault), ("active", u.IsActive), ("now", now) };
                var uid = u.Id;
                if (uid is null) { await Sql.Execute(c, t, "INSERT INTO item_units(tenant_id,company_id,item_id,unit_id,base_unit_id,to_base_factor,purchase_price,selling_price,is_purchase_default,is_sale_default,is_active,created_at,updated_at) VALUES(@tenant,@company,@item,@unit,@base,@factor,@purchase,@selling,@pd,@sd,@active,@now,@now)", ct, [.. Scope(current), .. values]); uid = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)); }
                else await Sql.Execute(c, t, "UPDATE item_units SET to_base_factor=@factor,purchase_price=@purchase,selling_price=@selling,is_purchase_default=@pd,is_sale_default=@sd,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND item_id=@item AND id=@uid", ct, [.. Scope(current), .. values, ("uid", uid)]);
                foreach (var b in u.Barcodes)
                {
                    if (b.Id is null) await Sql.Execute(c, t, "INSERT INTO item_barcodes(tenant_id,company_id,item_id,item_unit_id,barcode,is_active,created_at,updated_at) VALUES(@tenant,@company,@item,@unit,@barcode,@active,@now,@now)", ct, [.. Scope(current), ("item", id), ("unit", uid), ("barcode", b.Value), ("active", b.IsActive), ("now", now)]);
                    else await Sql.Execute(c, t, "UPDATE item_barcodes SET item_unit_id=@unit,barcode=@barcode,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND item_id=@item AND id=@bid", ct, [.. Scope(current), ("item", id), ("unit", uid), ("bid", b.Id), ("barcode", b.Value), ("active", b.IsActive), ("now", now)]);
                }
            }
            if (e.Units.Any(u => u.PurchasePrice.HasValue || u.SellingPrice.HasValue))
            {
                var locked = await Sql.Execute(c, t, "UPDATE companies SET currency_locked_at=@now,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND id=@company AND currency_locked_at IS NULL", ct, [.. Scope(current), ("now", now)]);
                if (locked > 0) await Audit(c, t, current, "CURRENCY_LOCKED", "COMPANY", current.Selected!.CompanyId, "First catalogue price configured", now, correlation, ct);
            }
            var saved = await Detail(c, t, current, id.Value, ct);
            var details = JsonSerializer.Serialize(new { before = old is null ? null : new { old.Product, old.Units, old.Barcodes }, after = new { saved.Product, saved.Units, saved.Barcodes } }, new JsonSerializerOptions { NumberHandling = JsonNumberHandling.WriteAsString });
            await IdentityStore.Audit(c, t, current.Selected!, "PRODUCT_SAVED", "ITEM", id.Value, e.Reason, now, correlation, ct, detailsJson: details);
            foreach (var action in new[] { "ITEM_UNITS_SAVED", "ITEM_PRICES_SAVED", "BARCODES_SAVED" }) await Audit(c, t, current, action, "ITEM", id.Value, e.Reason, now, correlation, ct);
            return saved;
        }, ct);
    }
    private static void ValidateBarcode(string value) { if (string.IsNullOrWhiteSpace(value) || value.Length > 128 || value != value.Trim() || value.Any(char.IsControl)) throw Invalid("Use 1–128 printable barcode characters without outer whitespace. Leading zeros are preserved."); }
    public Task<ProductDetail> BarcodeAsync(SessionData s, string value, CancellationToken ct)
    {
        ValidateBarcode(value); return Scoped(s, false, async (c, t, current, now) =>
        {
            var found = await Sql.Scalar(c, t, "SELECT b.item_id FROM item_barcodes b JOIN item_units iu ON iu.tenant_id=b.tenant_id AND iu.company_id=b.company_id AND iu.item_id=b.item_id AND iu.id=b.item_unit_id JOIN items i ON i.tenant_id=b.tenant_id AND i.company_id=b.company_id AND i.id=b.item_id JOIN units u ON u.tenant_id=iu.tenant_id AND u.company_id=iu.company_id AND u.id=iu.unit_id WHERE b.tenant_id=@tenant AND b.company_id=@company AND b.barcode=@value AND b.is_active=1 AND iu.is_active=1 AND i.is_active=1 AND u.is_active=1", ct, [.. Scope(current), ("value", value)]) ?? throw Missing(); return await Detail(c, t, current, Convert.ToUInt64(found), ct);
        }, ct);
    }
    public Task<decimal> ConvertAsync(SessionData s, ulong productId, ConversionInput input, CancellationToken ct) => Scoped(s, false, async (c, t, current, now) =>
    {
        var detail = await Detail(c, t, current, productId, ct); var row = detail.Units.SingleOrDefault(x => x.Id == input.ItemUnitId && x.IsActive) ?? throw Missing(); var masters = await Units(c, t, current, ct); var unit = masters.SingleOrDefault(x => x.Id == row.UnitId && x.IsActive) ?? throw Missing(); var baseUnit = masters.SingleOrDefault(x => x.Id == detail.Product.BaseUnitId && x.IsActive) ?? throw Missing();
        try { return CatalogNumbers.ToBase(input.Quantity, row.ToBaseFactor, unit.IsDiscrete, baseUnit.IsDiscrete); } catch (ArgumentException e) { throw Invalid(e.Message); }
    }, ct);
    public Task<IReadOnlyList<Supplier>> SuppliersAsync(SessionData s, CancellationToken ct) => Scoped<IReadOnlyList<Supplier>>(s, false, async (c, t, current, now) =>
    {
        var rows = await List(c, t, "SELECT * FROM parties WHERE tenant_id=@tenant AND company_id=@company AND is_supplier=1 AND (@admin=1 OR is_active=1) ORDER BY name,id LIMIT 1000", SupplierRow, ct, [.. Scope(current), ("admin", Admin(current))]);
        return Admin(current) ? rows : rows.Select(p => p with { Notes = null }).ToList();
    }, ct);
    public Task<Supplier> SaveSupplierAsync(SessionData s, ulong? id, SupplierEdit e, string correlation, CancellationToken ct)
    {
        var code = Code(e.Code, 60); Text(e.Name, 200, "supplier name", true); Text(e.Reason, 300, "reason", true); Text(e.Phone, 50, "phone"); Text(e.Email, 254, "email"); Text(e.Address, 700, "address"); Text(e.ContactPerson, 120, "contact person"); Text(e.Notes, 700, "notes"); if (!string.IsNullOrWhiteSpace(e.Email)) _ = IdentityService.NormalizeEmail(e.Email);
        return Scoped(s, true, async (c, t, current, now) =>
        {
            if (id is not null) { var previous = await Sql.One(c, t, "SELECT * FROM parties WHERE tenant_id=@tenant AND company_id=@company AND id=@id AND is_supplier=1", SupplierRow, ct, [.. Scope(current), ("id", id)]) ?? throw Missing(); Version(previous.Version, e.ExpectedVersion); }
            var args = new (string, object?)[] { ("code", code), ("name", e.Name.Trim()), ("phone", e.Phone), ("email", e.Email), ("address", e.Address), ("person", e.ContactPerson), ("notes", e.Notes), ("active", e.IsActive), ("now", now) };
            if (id is null) { await Sql.Execute(c, t, "INSERT INTO parties(tenant_id,company_id,code,name,phone,email,address,contact_person,notes,is_supplier,is_customer,is_active,created_at,updated_at) VALUES(@tenant,@company,@code,@name,@phone,@email,@address,@person,@notes,1,0,@active,@now,@now)", ct, [.. Scope(current), .. args]); id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)); }
            else await Sql.Execute(c, t, "UPDATE parties SET code=@code,name=@name,phone=@phone,email=@email,address=@address,contact_person=@person,notes=@notes,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id AND is_supplier=1", ct, [.. Scope(current), .. args, ("id", id)]);
            await Audit(c, t, current, "SUPPLIER_SAVED", "PARTY", id.Value, e.Reason, now, correlation, ct); return await Sql.One(c, t, "SELECT * FROM parties WHERE tenant_id=@tenant AND company_id=@company AND id=@id", SupplierRow, ct, [.. Scope(current), ("id", id)]) ?? throw Missing();
        }, ct);
    }
}

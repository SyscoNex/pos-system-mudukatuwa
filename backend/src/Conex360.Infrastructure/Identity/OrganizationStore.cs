using Conex360.Application.Identity;
using Conex360.Application.Organization;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed class OrganizationStore(Database database, AuthPolicy policy, OrganizationSettings settings,
    IPasswordService passwords, TimeProvider clock) : IOrganizationStore
{
    public async Task InitializeTransitAsync(Guid tenantPublicId, string operatorReference, string reason, CancellationToken ct)
    {
        Reason(reason); if (string.IsNullOrWhiteSpace(operatorReference) || operatorReference.Length > 100) throw Invalid("Verified operator is required.");
        if (!settings.Enabled) throw new AppFailure(503, "ORGANIZATION_UNAVAILABLE", "Outlet management has not been enabled.");
        await using var c = await database.OpenAsync(ct); await using var t = await c.BeginTransactionAsync(ct);
        var target = await Sql.One(c, t, "SELECT c.id,c.tenant_id FROM companies c JOIN tenants t ON t.id=c.tenant_id WHERE t.public_id=@public FOR UPDATE", r => new { Company = r.GetUInt64("id"), Tenant = r.GetUInt64("tenant_id") }, ct, ("public", tenantPublicId)) ?? throw Missing();
        await EnsureTransit(c, t, target.Tenant, target.Company, clock.GetUtcNow(), Guid.NewGuid().ToString(), operatorReference, ct);
        await t.CommitAsync(ct);
    }
    private static AppFailure Missing() => new(404, "NOT_FOUND", "The requested record is unavailable.");
    public async Task LinkExistingAsync(LinkExistingMembership input, string password, CancellationToken ct)
    {
        Reason(input.ConsentReference); if (string.IsNullOrWhiteSpace(input.OperatorReference) || input.OperatorReference.Length > 100 || input.Role is not (MembershipRoles.Administrator or MembershipRoles.Staff)) throw Invalid("Verified operator, consent and a static membership role are required.");
        if (!settings.Enabled) throw new AppFailure(503, "ORGANIZATION_UNAVAILABLE", "Outlet management has not been enabled.");
        var email = IdentityService.NormalizeEmail(input.Email);
        await using var c = await database.OpenAsync(ct); await using var t = await c.BeginTransactionAsync(ct);
        var user = await Sql.One(c, t, "SELECT id,password_hash,is_enabled,must_change_password,lockout_until FROM users WHERE public_id=@public AND email_normalized=@email FOR UPDATE", r => new { Id = r.GetUInt64("id"), Hash = r.GetString("password_hash"), Enabled = r.GetBoolean("is_enabled"), Forced = r.GetBoolean("must_change_password"), Until = Sql.Date(r, "lockout_until") }, ct, ("public", input.UserPublicId), ("email", email));
        if (user is null || !user.Enabled || user.Forced || user.Until > clock.GetUtcNow() || !passwords.Verify(email, user.Hash, password).Valid) throw new AppFailure(409, "LINKAGE_REJECTED", "The verified identity could not be linked.");
        var company = await Sql.One(c, t, "SELECT c.id,c.tenant_id FROM companies c JOIN tenants t ON t.id=c.tenant_id WHERE t.public_id=@public AND t.status='ACTIVE' FOR UPDATE", r => new { Id = r.GetUInt64("id"), Tenant = r.GetUInt64("tenant_id") }, ct, ("public", input.TenantPublicId)) ?? throw Missing();
        if (await Sql.Scalar(c, t, "SELECT id FROM tenant_memberships WHERE tenant_id=@tenant AND user_id=@user", ct, ("tenant", company.Tenant), ("user", user.Id)) is not null) throw new AppFailure(409, "LINKAGE_REJECTED", "The verified identity could not be linked.");
        var now = clock.GetUtcNow();
        await Sql.Execute(c, t, "INSERT INTO tenant_memberships(tenant_id,user_id,role,created_at,updated_at) VALUES(@tenant,@user,@role,@now,@now)", ct, ("tenant", company.Tenant), ("user", user.Id), ("role", input.Role), ("now", now));
        var id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
        await IdentityStore.Audit(c, t, new(id, company.Tenant, company.Id, "", input.Role), "EXISTING_IDENTITY_LINKED", "MEMBERSHIP", id, input.ConsentReference, now, Guid.NewGuid().ToString(), ct, input.OperatorReference);
        await t.CommitAsync(ct);
    }
    private static AppFailure Invalid(string message) => new(400, "INVALID_REQUEST", message);
    private static AppFailure Conflict() => new(409, "VERSION_CONFLICT", "This record changed. Refresh and try again.");
    private static void Reason(string value) { if (string.IsNullOrWhiteSpace(value) || value.Length > 300) throw Invalid("A reason of up to 300 characters is required."); }
    private static string Code(string value, int max)
    {
        value = value.Trim().ToUpperInvariant();
        if (value.Length is < 1 || value.Length > max || !value.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_') || value.StartsWith("SYS-", StringComparison.Ordinal)) throw Invalid("Use letters, digits, hyphens or underscores; SYS- codes are reserved.");
        return value;
    }
    private static void Name(string value) { if (string.IsNullOrWhiteSpace(value) || value.Length > 200) throw Invalid("Enter a name of up to 200 characters."); }
    private async Task<T> Scoped<T>(SessionData observed, bool admin, Func<MySqlConnection, MySqlTransaction, SessionData, DateTimeOffset, Task<T>> work, CancellationToken ct)
    {
        if (!settings.Enabled) throw new AppFailure(503, "ORGANIZATION_UNAVAILABLE", "Outlet management has not been enabled.");
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var now = clock.GetUtcNow();
        var current = await IdentityStore.Guard(c, t, observed, now, policy, true, admin, ct);
        try
        {
            var result = await work(c, t, current, now);
            await t.CommitAsync(ct); return result;
        }
        catch (MySqlException e) when (e.Number == 1062) { throw new AppFailure(409, "DUPLICATE_RECORD", "The code or account cannot be used. Verify existing records or contact SysConex for identity linkage."); }
    }
    private static (string, object?)[] Scope(SessionData s) => [("tenant", s.Selected!.TenantId), ("company", s.Selected.CompanyId)];
    private static async Task<List<T>> List<T>(MySqlConnection c, MySqlTransaction t, string sql, Func<MySqlDataReader, T> read, CancellationToken ct, params (string, object?)[] values)
    {
        await using var cmd = Sql.Command(c, t, sql, values); await using var r = await cmd.ExecuteReaderAsync(ct); var list = new List<T>();
        while (await r.ReadAsync(ct)) list.Add(read(r)); return list;
    }
    private static Outlet OutletRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetString("code"), r.GetString("name"), Sql.Text(r, "address"), Sql.Text(r, "phone"), Sql.Text(r, "description"), r.GetBoolean("is_active"), r.GetUInt64("row_version"));
    private static Warehouse WarehouseRow(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetUInt64("branch_id"), r.GetString("code"), r.GetString("name"), Sql.Text(r, "description"), r.GetBoolean("is_active"), r.GetBoolean("is_default"), r.GetUInt64("row_version"));
    private static Task<int> Audit(MySqlConnection c, MySqlTransaction t, SessionData s, string action, string entity, ulong id, string reason, DateTimeOffset now, string correlation, CancellationToken ct) =>
        IdentityStore.Audit(c, t, s.Selected!, action, entity, id, reason, now, correlation, ct);
    private static async Task<List<Outlet>> Accessible(MySqlConnection c, MySqlTransaction t, SessionData s, CancellationToken ct) =>
        await List(c, t, """
            SELECT b.* FROM branches b WHERE b.tenant_id=@tenant AND b.company_id=@company
            AND (@admin=1 OR (b.is_active=1 AND EXISTS(SELECT 1 FROM membership_branches g
            WHERE g.tenant_id=b.tenant_id AND g.company_id=b.company_id AND g.branch_id=b.id AND g.membership_id=@member AND g.is_active=1)))
            ORDER BY b.name,b.id LIMIT 1000
            """, OutletRow, ct, [.. Scope(s), ("admin", s.Selected!.Role == MembershipRoles.Administrator), ("member", s.Selected.Id)]);
    private static async Task<Outlet> Branch(MySqlConnection c, MySqlTransaction t, SessionData s, ulong id, bool active, CancellationToken ct) =>
        (await Accessible(c, t, s, ct)).SingleOrDefault(b => b.Id == id && (!active || b.IsActive)) ?? throw Missing();
    private static Task<int> Invalidate(MySqlConnection c, MySqlTransaction t, Membership m, ulong? member, CancellationToken ct) =>
        Sql.Execute(c, t, """
            UPDATE auth_sessions s JOIN tenant_memberships m ON m.id=s.selected_membership_id AND m.user_id=s.user_id
            SET s.context_version=s.context_version+1,s.selected_branch_id=NULL,s.selected_branch_tenant_id=NULL,s.selected_branch_company_id=NULL,s.row_version=s.row_version+1
            WHERE m.tenant_id=@tenant AND (@member IS NULL OR m.id=@member) AND s.revoked_at IS NULL
            """, ct, ("tenant", m.TenantId), ("member", member));
    internal static async Task EnsureTransit(MySqlConnection c, MySqlTransaction t, ulong tenant, ulong company, DateTimeOffset now, string correlation, string op, CancellationToken ct)
    {
        await Sql.Scalar(c, t, "SELECT id FROM companies WHERE tenant_id=@tenant AND id=@company FOR UPDATE", ct, ("tenant", tenant), ("company", company));
        var found = await Sql.Scalar(c, t, "SELECT id FROM warehouses WHERE tenant_id=@tenant AND company_id=@company AND kind='TRANSIT'", ct, ("tenant", tenant), ("company", company));
        if (found is not null) return;
        await Sql.Execute(c, t, "INSERT INTO warehouses(tenant_id,company_id,code,name,kind,created_at,updated_at) VALUES(@tenant,@company,'SYS-TRANSIT','Internal transit','TRANSIT',@now,@now)", ct, ("tenant", tenant), ("company", company), ("now", now));
        var id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
        await Sql.Execute(c, t, "INSERT INTO locations(tenant_id,company_id,warehouse_id,warehouse_kind,code,name,kind,created_at,updated_at) VALUES(@tenant,@company,@id,'TRANSIT','TRANSIT','In transit','TRANSIT',@now,@now)", ct, ("tenant", tenant), ("company", company), ("id", id), ("now", now));
        await IdentityStore.Audit(c, t, new(0, tenant, company, "", MembershipRoles.Administrator), "TRANSIT_INITIALIZED", "WAREHOUSE", id, "Internal warehouse initialization", now, correlation, ct, op);
    }
    private static async Task<ulong> CreateWarehouse(MySqlConnection c, MySqlTransaction t, SessionData s, ulong branch, string code, string name, string? description, bool defaultWarehouse, DateTimeOffset now, CancellationToken ct)
    {
        await Sql.Execute(c, t, "INSERT INTO warehouses(tenant_id,company_id,branch_id,code,name,description,kind,is_default,created_at,updated_at) VALUES(@tenant,@company,@branch,@code,@name,@description,'ORDINARY',@default,@now,@now)", ct, [.. Scope(s), ("branch", branch), ("code", code), ("name", name), ("description", description), ("default", defaultWarehouse), ("now", now)]);
        var id = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
        foreach (var kind in new[] { "STORAGE", "HOLD", "DAMAGED" })
            await Sql.Execute(c, t, "INSERT INTO locations(tenant_id,company_id,warehouse_id,warehouse_kind,code,name,kind,created_at,updated_at) VALUES(@tenant,@company,@id,'ORDINARY',@kind,@kind,@kind,@now,@now)", ct, [.. Scope(s), ("id", id), ("kind", kind), ("now", now)]);
        return id;
    }
    public Task<IReadOnlyList<Outlet>> OutletsAsync(SessionData s, CancellationToken ct) => Scoped<IReadOnlyList<Outlet>>(s, false, async (c, t, current, unusedTime) => await Accessible(c, t, current, ct), ct);
    public Task<Outlet> SaveOutletAsync(SessionData s, ulong? id, OutletEdit e, string correlation, CancellationToken ct)
    {
        Reason(e.Reason); Name(e.Name); var code = Code(e.Code, 40);
        if (e.Address?.Length > 700 || e.Phone?.Length > 50 || e.Description?.Length > 500) throw Invalid("Check contact and description lengths.");
        return Scoped(s, true, async (c, t, current, now) =>
        {
            var branch = id;
            if (id is null)
            {
                if (!e.IsActive) throw Invalid("Create the outlet active, then deactivate it with a reason if needed.");
                await Sql.Execute(c, t, "INSERT INTO branches(tenant_id,company_id,code,name,address,phone,description,created_at,updated_at) VALUES(@tenant,@company,@code,@name,@address,@phone,@description,@now,@now)", ct, [.. Scope(current), ("code", code), ("name", e.Name.Trim()), ("address", e.Address), ("phone", e.Phone), ("description", e.Description), ("now", now)]);
                branch = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
                var warehouse = await CreateWarehouse(c, t, current, branch.Value, code + "-MAIN", "Main warehouse", null, true, now, ct);
                await Audit(c, t, current, "WAREHOUSE_CREATED", "WAREHOUSE", warehouse, e.Reason, now, correlation, ct);
            }
            else
            {
                var old = await Branch(c, t, current, id.Value, false, ct); if (old.Version != e.ExpectedVersion) throw Conflict();
                if (!e.IsActive) await InventoryStore.RequireEmptyLocationAsync(c, t, current.Selected!, null, id, ct);
                await Sql.Execute(c, t, "UPDATE branches SET code=@code,name=@name,address=@address,phone=@phone,description=@description,is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("id", id), ("code", code), ("name", e.Name.Trim()), ("address", e.Address), ("phone", e.Phone), ("description", e.Description), ("active", e.IsActive), ("now", now)]);
                if (old.IsActive != e.IsActive)
                {
                    var changed = await List(c, t, "SELECT * FROM warehouses WHERE tenant_id=@tenant AND company_id=@company AND branch_id=@id AND kind='ORDINARY' AND (@active=0 OR is_default=1)", WarehouseRow, ct, [.. Scope(current), ("id", id), ("active", e.IsActive)]);
                    foreach (var w in changed)
                    {
                        await Sql.Execute(c, t, "UPDATE warehouses SET is_active=@active,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("id", w.Id), ("active", e.IsActive), ("now", now)]);
                        await Audit(c, t, current, "WAREHOUSE_STATUS_CHANGED", "WAREHOUSE", w.Id, e.Reason, now, correlation, ct);
                    }
                    if (!e.IsActive)
                    {
                        var grants = await List(c, t, "SELECT membership_id FROM membership_branches WHERE tenant_id=@tenant AND company_id=@company AND branch_id=@id AND is_active=1", r => r.GetUInt64(0), ct, [.. Scope(current), ("id", id)]);
                        await Sql.Execute(c, t, "UPDATE membership_branches SET is_active=0,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND branch_id=@id AND is_active=1", ct, [.. Scope(current), ("id", id), ("now", now)]);
                        foreach (var member in grants) await Audit(c, t, current, "OUTLET_GRANTS_CHANGED", "MEMBERSHIP", member, e.Reason, now, correlation, ct);
                    }
                    await Invalidate(c, t, current.Selected!, null, ct);
                }
            }
            await Audit(c, t, current, id is null ? "OUTLET_CREATED" : "OUTLET_UPDATED", "BRANCH", branch!.Value, e.Reason, now, correlation, ct);
            return await Branch(c, t, current, branch.Value, false, ct);
        }, ct);
    }
    private static Task<List<Warehouse>> Warehouses(MySqlConnection c, MySqlTransaction t, SessionData s, ulong? branch, CancellationToken ct) =>
        List(c, t, """
        SELECT w.* FROM warehouses w JOIN branches b ON b.tenant_id=w.tenant_id AND b.company_id=w.company_id AND b.id=w.branch_id
        WHERE w.tenant_id=@tenant AND w.company_id=@company AND w.kind='ORDINARY' AND (@branch IS NULL OR w.branch_id=@branch)
        AND (@admin=1 OR (b.is_active=1 AND w.is_active=1 AND EXISTS(SELECT 1 FROM membership_branches g WHERE g.tenant_id=w.tenant_id AND g.company_id=w.company_id AND g.branch_id=w.branch_id AND g.membership_id=@member AND g.is_active=1)))
        ORDER BY b.name,w.name,w.id LIMIT 1000
        """, WarehouseRow, ct, [.. Scope(s), ("branch", branch), ("admin", s.Selected!.Role == MembershipRoles.Administrator), ("member", s.Selected.Id)]);
    public Task<IReadOnlyList<Warehouse>> WarehousesAsync(SessionData s, ulong? branchId, CancellationToken ct) => Scoped<IReadOnlyList<Warehouse>>(s, false, async (c, t, current, unusedTime) =>
    {
        if (branchId is { } b) _ = await Branch(c, t, current, b, current.Selected!.Role != MembershipRoles.Administrator, ct);
        return await Warehouses(c, t, current, branchId, ct);
    }, ct);
    public Task<Warehouse> SaveWarehouseAsync(SessionData s, ulong? id, WarehouseEdit e, string correlation, CancellationToken ct)
    {
        Reason(e.Reason); Name(e.Name); var code = Code(e.Code, 60); if (e.Description?.Length > 500) throw Invalid("Description is too long.");
        return Scoped(s, true, async (c, t, current, now) =>
        {
            _ = await Branch(c, t, current, e.BranchId, true, ct);
            var all = await Warehouses(c, t, current, e.BranchId, ct); var old = id is null ? null : all.SingleOrDefault(w => w.Id == id) ?? throw Missing();
            if (id is not null && !e.IsActive) await InventoryStore.RequireEmptyLocationAsync(c, t, current.Selected!, id, null, ct);
            if (old is not null && old.Version != e.ExpectedVersion) throw Conflict();
            if (!e.IsActive && e.IsDefault) throw Invalid("An active outlet needs an active default warehouse.");
            if (old?.IsDefault == true && !e.IsDefault)
            {
                var replacement = all.SingleOrDefault(w => w.Id == e.ReplacementWarehouseId && w.Id != id && w.IsActive) ?? throw Invalid("Select an active replacement default warehouse.");
                await Sql.Execute(c, t, "UPDATE warehouses SET is_default=0,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("now", now), ("id", id)]);
                await Sql.Execute(c, t, "UPDATE warehouses SET is_default=1,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("now", now), ("id", replacement.Id)]);
                await Audit(c, t, current, "DEFAULT_WAREHOUSE_CHANGED", "WAREHOUSE", replacement.Id, e.Reason, now, correlation, ct);
            }
            if (e.IsDefault)
            {
                await Sql.Execute(c, t, "UPDATE warehouses SET is_default=0,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND branch_id=@branch AND kind='ORDINARY' AND is_default=1 AND (@id IS NULL OR id<>@id)", ct, [.. Scope(current), ("branch", e.BranchId), ("id", id), ("now", now)]);
            }
            var warehouse = id;
            if (id is null)
            {
                warehouse = await CreateWarehouse(c, t, current, e.BranchId, code, e.Name.Trim(), e.Description, e.IsDefault, now, ct);
                if (!e.IsActive) await Sql.Execute(c, t, "UPDATE warehouses SET is_active=0 WHERE tenant_id=@tenant AND company_id=@company AND id=@id", ct, [.. Scope(current), ("id", warehouse)]);
            }
            else await Sql.Execute(c, t, "UPDATE warehouses SET code=@code,name=@name,description=@description,is_active=@active,is_default=@default,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND id=@id AND branch_id=@branch AND kind='ORDINARY'", ct, [.. Scope(current), ("id", id), ("branch", e.BranchId), ("code", code), ("name", e.Name.Trim()), ("description", e.Description), ("active", e.IsActive), ("default", e.IsDefault), ("now", now)]);
            await Audit(c, t, current, id is null ? "WAREHOUSE_CREATED" : "WAREHOUSE_UPDATED", "WAREHOUSE", warehouse!.Value, e.Reason, now, correlation, ct);
            if (e.IsDefault) await Audit(c, t, current, "DEFAULT_WAREHOUSE_CHANGED", "WAREHOUSE", warehouse.Value, e.Reason, now, correlation, ct);
            return (await Warehouses(c, t, current, e.BranchId, ct)).Single(w => w.Id == warehouse);
        }, ct);
    }
    public Task<IReadOnlyList<StorageLocation>> LocationsAsync(SessionData s, ulong warehouseId, CancellationToken ct) => Scoped<IReadOnlyList<StorageLocation>>(s, false, async (c, t, current, unusedTime) =>
    {
        if (!(await Warehouses(c, t, current, null, ct)).Any(w => w.Id == warehouseId)) throw Missing();
        return await List(c, t, "SELECT * FROM locations WHERE tenant_id=@tenant AND company_id=@company AND warehouse_id=@id AND warehouse_kind='ORDINARY' ORDER BY kind", r => new StorageLocation(r.GetUInt64("id"), r.GetUInt64("warehouse_id"), r.GetString("code"), r.GetString("name"), r.GetString("kind")), ct, [.. Scope(current), ("id", warehouseId)]);
    }, ct);
    public Task<IReadOnlyList<ManagedUser>> UsersAsync(SessionData s, CancellationToken ct) => Scoped<IReadOnlyList<ManagedUser>>(s, true, async (c, t, current, unusedTime) =>
    {
        var rows = await List(c, t, "SELECT m.*,u.display_name,u.email_normalized,u.is_enabled,u.must_change_password FROM tenant_memberships m JOIN users u ON u.id=m.user_id WHERE m.tenant_id=@tenant ORDER BY u.display_name,m.id LIMIT 1000",
            r => new ManagedUser(r.GetUInt64("id"), r.GetString("display_name"), r.GetString("email_normalized"), r.GetString("role"), r.GetString("status") == "ACTIVE", r.GetBoolean("is_enabled"), r.GetBoolean("must_change_password"), r.GetUInt64("row_version"), []), ct, Scope(current));
        var list = new List<ManagedUser>();
        foreach (var row in rows) list.Add(row with { BranchIds = await List(c, t, "SELECT branch_id FROM membership_branches WHERE tenant_id=@tenant AND company_id=@company AND membership_id=@member AND is_active=1 ORDER BY branch_id", r => r.GetUInt64(0), ct, [.. Scope(current), ("member", row.MembershipId)]) });
        return list;
    }, ct);
    private static async Task Grants(MySqlConnection c, MySqlTransaction t, SessionData current, ulong member, IReadOnlyList<ulong> branches, DateTimeOffset now, CancellationToken ct)
    {
        if (branches.Count > 1000 || branches.Distinct().Count() != branches.Count) throw Invalid("Check the selected outlets.");
        foreach (var branch in branches) _ = await Branch(c, t, current, branch, true, ct);
        await Sql.Execute(c, t, "UPDATE membership_branches SET is_active=0,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND company_id=@company AND membership_id=@member AND is_active=1", ct, [.. Scope(current), ("member", member), ("now", now)]);
        foreach (var branch in branches) await Sql.Execute(c, t, """
            INSERT INTO membership_branches(tenant_id,company_id,membership_id,branch_id,created_at,updated_at) VALUES(@tenant,@company,@member,@branch,@now,@now)
            ON DUPLICATE KEY UPDATE is_active=1,updated_at=@now,row_version=row_version+1
            """, ct, [.. Scope(current), ("member", member), ("branch", branch), ("now", now)]);
    }
    public Task<InitialCredential> CreateStaffAsync(SessionData s, CreateStaff input, string correlation, CancellationToken ct)
    {
        Reason(input.Reason); if (string.IsNullOrWhiteSpace(input.DisplayName) || input.DisplayName.Length > 120) throw Invalid("Enter a display name of up to 120 characters.");
        var email = IdentityService.NormalizeEmail(input.Email); var secret = SessionSecrets.Create(); var hash = passwords.Hash(email, secret);
        return Scoped(s, true, async (c, t, current, now) =>
        {
            if (await Sql.Scalar(c, t, "SELECT id FROM users WHERE email_normalized=@email", ct, ("email", email)) is not null)
                throw new AppFailure(409, "DUPLICATE_RECORD", "The code or account cannot be used. Verify existing records or contact SysConex for identity linkage.");
            await Sql.Execute(c, t, "INSERT INTO users(public_id,email_normalized,display_name,password_hash,security_stamp,created_at,updated_at) VALUES(@public,@email,@name,@hash,@stamp,@now,@now)", ct, ("public", Guid.NewGuid()), ("email", email), ("name", input.DisplayName.Trim()), ("hash", hash), ("stamp", Guid.NewGuid()), ("now", now));
            var user = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
            await Sql.Execute(c, t, "INSERT INTO tenant_memberships(tenant_id,user_id,role,created_at,updated_at) VALUES(@tenant,@user,'STAFF',@now,@now)", ct, ("tenant", current.Selected!.TenantId), ("user", user), ("now", now));
            var member = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
            await Grants(c, t, current, member, input.BranchIds, now, ct);
            await Audit(c, t, current, "MEMBERSHIP_CREATED", "MEMBERSHIP", member, input.Reason, now, correlation, ct);
            await Audit(c, t, current, "OUTLET_GRANTS_CHANGED", "MEMBERSHIP", member, input.Reason, now, correlation, ct);
            return new InitialCredential(member, email, secret);
        }, ct);
    }
    public Task UpdateMemberAsync(SessionData s, ulong member, MemberEdit e, string correlation, CancellationToken ct)
    {
        Reason(e.Reason); if (e.Role is not (MembershipRoles.Administrator or MembershipRoles.Staff)) throw Invalid("Choose Administrator or Staff.");
        return Scoped(s, true, async (c, t, current, now) =>
        {
            var target = await Sql.One(c, t, "SELECT * FROM tenant_memberships WHERE tenant_id=@tenant AND id=@id FOR UPDATE", r => new { Role = r.GetString("role"), Status = r.GetString("status"), Version = r.GetUInt64("row_version") }, ct, ("tenant", current.Selected!.TenantId), ("id", member)) ?? throw Missing();
            if (target.Version != e.ExpectedVersion) throw Conflict();
            if (target.Role == MembershipRoles.Administrator && target.Status == "ACTIVE" && (!e.IsActive || e.Role != MembershipRoles.Administrator))
            {
                var count = Convert.ToInt32(await Sql.Scalar(c, t, "SELECT COUNT(*) FROM tenant_memberships m JOIN users u ON u.id=m.user_id WHERE m.tenant_id=@tenant AND m.role='ADMINISTRATOR' AND m.status='ACTIVE' AND u.is_enabled=1", ct, ("tenant", current.Selected.TenantId)));
                if (count <= 1) throw new AppFailure(409, "LAST_ADMINISTRATOR", "Keep at least one active Administrator.");
            }
            await Grants(c, t, current, member, e.BranchIds, now, ct);
            await Sql.Execute(c, t, "UPDATE tenant_memberships SET role=@role,status=@status,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND id=@id", ct, ("tenant", current.Selected.TenantId), ("id", member), ("role", e.Role), ("status", e.IsActive ? "ACTIVE" : "DISABLED"), ("now", now));
            await Invalidate(c, t, current.Selected, member, ct);
            await Audit(c, t, current, "MEMBERSHIP_UPDATED", "MEMBERSHIP", member, e.Reason, now, correlation, ct);
            await Audit(c, t, current, "OUTLET_GRANTS_CHANGED", "MEMBERSHIP", member, e.Reason, now, correlation, ct);
            return true;
        }, ct);
    }
    public Task<OutletContext> ContextAsync(SessionData s, CancellationToken ct) => Scoped(s, false, async (c, t, current, unusedTime) =>
    {
        var outlets = (await Accessible(c, t, current, ct)).Where(b => b.IsActive).ToArray();
        return new OutletContext(outlets.Any(b => b.Id == current.Session.SelectedBranchId) ? current.Session.SelectedBranchId : null, current.Session.ContextVersion, outlets);
    }, ct);
    public Task<OutletContext> SelectOutletAsync(SessionData s, ulong? branchId, string correlation, CancellationToken ct) => Scoped(s, false, async (c, t, current, now) =>
    {
        if (branchId is { } id) _ = await Branch(c, t, current, id, true, ct);
        else if (current.Selected!.Role != MembershipRoles.Administrator) throw Invalid("Select an assigned active outlet.");
        await Sql.Execute(c, t, "UPDATE auth_sessions SET selected_branch_id=@branch,selected_branch_tenant_id=@tenant,selected_branch_company_id=@company,context_version=context_version+1,row_version=row_version+1 WHERE public_id=@session", ct,
            ("branch", branchId), ("tenant", branchId.HasValue ? current.Selected!.TenantId : null), ("company", branchId.HasValue ? current.Selected!.CompanyId : null), ("session", current.Session.PublicId));
        return new OutletContext(branchId, current.Session.ContextVersion + 1, (await Accessible(c, t, current, ct)).Where(b => b.IsActive).ToArray());
    }, ct);
}

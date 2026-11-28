using System.Data;
using Conex360.Application.Identity;
using Conex360.Domain.Identity;
using MySqlConnector;

namespace Conex360.Infrastructure.Identity;

public sealed class IdentityStore(Database database, Conex360.Application.Organization.OrganizationSettings organization) : IIdentityStore
{
    private static UserAccount ReadUser(MySqlDataReader r) => new(r.GetUInt64("id"), Sql.Guid(r, "public_id"),
        r.GetString("email_normalized"), r.GetString("display_name"), r.GetString("password_hash"), Sql.Guid(r, "security_stamp"),
        r.GetBoolean("is_enabled"), r.GetBoolean("must_change_password"), r.GetUInt32("failed_access_count"), Sql.Date(r, "lockout_until"), r.GetUInt64("row_version"));
    private static SessionRecord ReadSession(MySqlDataReader r) => new(Sql.Guid(r, "public_id"), (byte[])r["session_key_hash"],
        r.GetUInt64("user_id"), Sql.Guid(r, "user_security_stamp"), r["selected_membership_id"] is DBNull ? null : r.GetUInt64("selected_membership_id"),
        r.GetUInt64("context_version"), Sql.Date(r, "created_at")!.Value, Sql.Date(r, "last_activity_at")!.Value,
        Sql.Date(r, "absolute_expires_at")!.Value, Sql.Date(r, "revoked_at"))
    { SelectedBranchId = OptionalBranch(r) };
    private static ulong? OptionalBranch(MySqlDataReader r)
    {
        for (var i = 0; i < r.FieldCount; i++) if (r.GetName(i) == "selected_branch_id") return r.IsDBNull(i) ? null : r.GetUInt64(i);
        return null; // Preserve operation against 0002 until migration execution is approved.
    }
    private static BusinessProfile ReadBusiness(MySqlDataReader r) => new(r.GetUInt64("id"), r.GetUInt64("tenant_id"),
        r.GetString("business_name"), r.GetString("display_name"), Sql.Text(r, "phone"), Sql.Text(r, "email"), Sql.Text(r, "address"),
        r.GetString("timezone"), r.GetString("currency_code"), r.GetByte("currency_minor_units"), Sql.Text(r, "logo_key"), r.GetUInt64("row_version"));
    private static AppFailure Unauthorized() => new(401, "SESSION_EXPIRED", "Your session has ended. Sign in again.");
    private static AppFailure Forbidden() => new(403, "FORBIDDEN", "This operation is not available for your business access.");
    private static AppFailure Conflict() => new(409, "VERSION_CONFLICT", "The information changed. Refresh and try again.");

    public async Task<UserAccount?> FindUserAsync(string normalizedEmail, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        return await Sql.One(c, null, "SELECT * FROM users WHERE email_normalized=@email", ReadUser, ct, ("email", normalizedEmail));
    }
    private static async Task<List<Membership>> Memberships(MySqlConnection c, MySqlTransaction t, ulong user, bool locked, CancellationToken ct)
    {
        await using var command = Sql.Command(c, t, """
            SELECT m.id,m.tenant_id,c.id AS company_id,c.display_name,m.role
            FROM tenant_memberships m JOIN tenants t ON t.id=m.tenant_id
            JOIN companies c ON c.tenant_id=m.tenant_id
            WHERE m.user_id=@user AND m.status='ACTIVE' AND t.status='ACTIVE'
            ORDER BY m.id
            """ + (locked ? " FOR UPDATE" : ""), ("user", user));
        await using var r = await command.ExecuteReaderAsync(ct);
        var list = new List<Membership>();
        while (await r.ReadAsync(ct)) list.Add(new(r.GetUInt64("id"), r.GetUInt64("tenant_id"), r.GetUInt64("company_id"), r.GetString("display_name"), r.GetString("role")));
        return list;
    }
    public async Task<SessionData?> FindSessionAsync(byte[] hash, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(IsolationLevel.RepeatableRead, ct);
        var session = await Sql.One(c, t, "SELECT * FROM auth_sessions WHERE session_key_hash=@hash", ReadSession, ct, ("hash", hash));
        if (session is null) return null;
        var user = await Sql.One(c, t, "SELECT * FROM users WHERE id=@id", ReadUser, ct, ("id", session.UserId));
        return user is null ? null : new(user, session, await Memberships(c, t, user.Id, false, ct));
    }
    internal static async Task<SessionData> Guard(MySqlConnection c, MySqlTransaction t, SessionData observed, DateTimeOffset now, AuthPolicy policy, bool business, bool admin, CancellationToken ct)
    {
        var user = await Sql.One(c, t, "SELECT * FROM users WHERE id=@id FOR UPDATE", ReadUser, ct, ("id", observed.User.Id)) ?? throw Unauthorized();
        var session = await Sql.One(c, t, "SELECT * FROM auth_sessions WHERE public_id=@id AND user_id=@user FOR UPDATE", ReadSession, ct, ("id", observed.Session.PublicId), ("user", user.Id)) ?? throw Unauthorized();
        var data = new SessionData(user, session, await Memberships(c, t, user.Id, true, ct));
        if (!data.IsValid(now, policy.Idle) || data.Memberships.Count == 0) throw Unauthorized();
        if (session.ContextVersion != observed.Session.ContextVersion) throw new AppFailure(409, "CONTEXT_CHANGED", "Your business context changed. Refresh before continuing.");
        if (business && (user.MustChangePassword || data.Selected is null || admin && data.Selected.Role != MembershipRoles.Administrator)) throw Forbidden();
        return data;
    }
    private static Task<int> Security(MySqlConnection c, MySqlTransaction? t, ulong? user, string code, DateTimeOffset now, string correlation, CancellationToken ct, string? op = null) =>
        Sql.Execute(c, t, "INSERT INTO security_events(user_id,event_code,operator_reference,correlation_id,occurred_at) VALUES(@user,@code,@op,@correlation,@now)", ct,
            ("user", user), ("code", code), ("op", op), ("correlation", correlation), ("now", now));
    internal static Task<int> Audit(MySqlConnection c, MySqlTransaction t, Membership m, string action, string entity, ulong entityId, string reason, DateTimeOffset now, string correlation, CancellationToken ct, string? op = null, string? detailsJson = null) =>
        Sql.Execute(c, t, """
            INSERT INTO audit_events(tenant_id,company_id,actor_membership_id,operator_reference,action,entity_type,entity_id,reason,correlation_id,occurred_at,details_json)
            VALUES(@tenant,@company,@actor,@op,@action,@entity,@id,@reason,@correlation,@now,@details)
            """, ct, ("tenant", m.TenantId), ("company", m.CompanyId), ("actor", op is null ? m.Id : null), ("op", op),
            ("action", action), ("entity", entity), ("id", entityId), ("reason", reason), ("correlation", correlation), ("now", now), ("details", detailsJson));
    private static Task<int> InsertSession(MySqlConnection c, MySqlTransaction t, SessionRecord s, CancellationToken ct) =>
        Sql.Execute(c, t, """
            INSERT INTO auth_sessions(public_id,session_key_hash,user_id,user_security_stamp,selected_membership_id,context_version,created_at,last_activity_at,absolute_expires_at)
            VALUES(@public,@hash,@user,@stamp,@membership,@context,@created,@activity,@expires)
            """, ct, ("public", s.PublicId), ("hash", s.KeyHash), ("user", s.UserId), ("stamp", s.SecurityStamp), ("membership", s.SelectedMembershipId),
            ("context", s.ContextVersion), ("created", s.CreatedAt), ("activity", s.LastActivityAt), ("expires", s.AbsoluteExpiresAt));

    public async Task<SessionData?> CommitLoginAsync(LoginCommit command, AuthPolicy policy, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var user = await Sql.One(c, t, "SELECT * FROM users WHERE id=@id FOR UPDATE", ReadUser, ct, ("id", command.Observed.Id));
        if (user is null) return null;
        var memberships = await Memberships(c, t, user.Id, true, ct);
        var valid = command.PasswordValid && user.PasswordHash == command.Observed.PasswordHash && user.SecurityStamp == command.Observed.SecurityStamp
            && user.IsEnabled && !(user.LockoutUntil > command.Now) && memberships.Count > 0;
        if (!valid)
        {
            if (user.IsEnabled && !(user.LockoutUntil > command.Now))
            {
                var failure = LoginRules.Failed(user, command.Now, policy.FailedAttempts, TimeSpan.FromMinutes(policy.LockoutMinutes));
                await Sql.Execute(c, t, "UPDATE users SET failed_access_count=@count,lockout_until=@until,updated_at=@now,row_version=row_version+1 WHERE id=@id", ct,
                    ("count", failure.Count), ("until", failure.LockoutUntil), ("now", command.Now), ("id", user.Id));
            }
            await Security(c, t, user.Id, "SIGN_IN_FAILED", command.Now, command.CorrelationId, ct);
            await t.CommitAsync(ct);
            return null;
        }
        await Sql.Execute(c, t, "UPDATE users SET failed_access_count=0,lockout_until=NULL,password_hash=@hash,updated_at=@now,row_version=row_version+1 WHERE id=@id", ct,
            ("hash", command.RehashedPassword ?? user.PasswordHash), ("now", command.Now), ("id", user.Id));
        var session = command.NewSession with { SelectedMembershipId = memberships.Count == 1 ? memberships[0].Id : null };
        await InsertSession(c, t, session, ct);
        await Security(c, t, user.Id, "SIGN_IN_SUCCEEDED", command.Now, command.CorrelationId, ct);
        await t.CommitAsync(ct);
        return new(user with { PasswordHash = command.RehashedPassword ?? user.PasswordHash }, session, memberships);
    }
    public async Task RecordUnknownFailureAsync(DateTimeOffset now, string correlation, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await Security(c, null, null, "SIGN_IN_FAILED", now, correlation, ct);
    }
    public async Task TouchAsync(SessionData session, DateTimeOffset now, AuthPolicy policy, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var data = await Guard(c, t, session, now, policy, false, false, ct);
        if (now - data.Session.LastActivityAt >= TimeSpan.FromMinutes(1))
            await Sql.Execute(c, t, "UPDATE auth_sessions SET last_activity_at=@now,row_version=row_version+1 WHERE public_id=@id", ct, ("now", now), ("id", data.Session.PublicId));
        await t.CommitAsync(ct);
    }
    public async Task RevokeAsync(ulong userId, Guid sessionPublicId, DateTimeOffset now, string correlation, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        await Sql.Scalar(c, t, "SELECT id FROM users WHERE id=@user FOR UPDATE", ct, ("user", userId));
        await Sql.Execute(c, t, "UPDATE auth_sessions SET revoked_at=@now,revocation_reason='LOGOUT',row_version=row_version+1 WHERE public_id=@id AND user_id=@user AND revoked_at IS NULL", ct,
            ("now", now), ("id", sessionPublicId), ("user", userId));
        await Security(c, t, userId, "SIGNED_OUT", now, correlation, ct);
        await t.CommitAsync(ct);
    }
    public async Task<SessionData> SelectMembershipAsync(SessionData session, ulong membershipId, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var current = await Guard(c, t, session, now, policy, false, false, ct);
        if (!current.Memberships.Any(m => m.Id == membershipId)) throw Forbidden();
        await Sql.Execute(c, t, "UPDATE auth_sessions SET " + (organization.Enabled ? "selected_branch_id=NULL,selected_branch_tenant_id=NULL,selected_branch_company_id=NULL," : "") + "selected_membership_id=@membership,context_version=context_version+1,last_activity_at=@now,row_version=row_version+1 WHERE public_id=@id", ct,
            ("membership", membershipId), ("now", now), ("id", current.Session.PublicId));
        await Security(c, t, current.User.Id, "CONTEXT_SELECTED", now, correlation, ct);
        await t.CommitAsync(ct);
        return current with { Session = current.Session with { SelectedMembershipId = membershipId, ContextVersion = current.Session.ContextVersion + 1 } };
    }
    public async Task<SessionData> ChangePasswordAsync(SessionData session, string expectedHash, string newHash, SessionRecord replacement, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var current = await Guard(c, t, session, now, policy, false, false, ct);
        if (current.User.PasswordHash != expectedHash) throw Unauthorized();
        await Sql.Execute(c, t, "UPDATE users SET password_hash=@hash,security_stamp=@stamp,must_change_password=FALSE,failed_access_count=0,lockout_until=NULL,updated_at=@now,row_version=row_version+1 WHERE id=@id", ct,
            ("hash", newHash), ("stamp", replacement.SecurityStamp), ("now", now), ("id", current.User.Id));
        await RevokeAll(c, t, current.User.Id, now, "PASSWORD_CHANGED", ct);
        await InsertSession(c, t, replacement, ct);
        await Security(c, t, current.User.Id, "PASSWORD_CHANGED", now, correlation, ct);
        await t.CommitAsync(ct);
        return current with { User = current.User with { PasswordHash = newHash, SecurityStamp = replacement.SecurityStamp, MustChangePassword = false }, Session = replacement };
    }
    private static Task<int> RevokeAll(MySqlConnection c, MySqlTransaction t, ulong user, DateTimeOffset now, string reason, CancellationToken ct) =>
        Sql.Execute(c, t, "UPDATE auth_sessions SET revoked_at=@now,revocation_reason=@reason,row_version=row_version+1 WHERE user_id=@id AND revoked_at IS NULL", ct,
            ("now", now), ("reason", reason), ("id", user));
    private static Task<BusinessProfile?> Business(MySqlConnection c, MySqlTransaction t, Membership m, CancellationToken ct) =>
        Sql.One(c, t, "SELECT * FROM companies WHERE tenant_id=@tenant AND id=@company FOR UPDATE", ReadBusiness, ct, ("tenant", m.TenantId), ("company", m.CompanyId));
    public async Task<BusinessProfile> GetBusinessAsync(SessionData session, AuthPolicy policy, DateTimeOffset now, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var current = await Guard(c, t, session, now, policy, true, false, ct);
        var business = await Business(c, t, current.Selected!, ct) ?? throw Forbidden();
        await t.CommitAsync(ct);
        return business;
    }
    private async Task<BusinessProfile> EditBusiness(SessionData session, BusinessEdit? edit, byte minorUnits, string? logo, ulong version, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var current = await Guard(c, t, session, now, policy, true, true, ct);
        var m = current.Selected!;
        var old = await Business(c, t, m, ct) ?? throw Forbidden();
        if (old.Version != version) throw Conflict();
        if (edit is not null)
        {
            var locked = await Sql.Scalar(c, t, "SELECT currency_locked_at FROM companies WHERE tenant_id=@tenant AND id=@id", ct, ("tenant", m.TenantId), ("id", m.CompanyId));
            if (locked is not DBNull && locked is not null && (old.CurrencyCode != edit.CurrencyCode || old.CurrencyMinorUnits != minorUnits))
                throw new AppFailure(409, "CURRENCY_LOCKED", "Currency cannot change after prices or operational amounts are configured.");
            await Sql.Execute(c, t, """
                UPDATE companies SET business_name=@name,display_name=@display,phone=@phone,email=@email,address=@address,timezone=@timezone,
                currency_code=@currency,currency_minor_units=@minor,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND id=@id AND row_version=@version
                """, ct, ("name", edit.BusinessName), ("display", edit.DisplayName), ("phone", edit.Phone), ("email", edit.Email), ("address", edit.Address),
                ("timezone", edit.Timezone), ("currency", edit.CurrencyCode), ("minor", minorUnits), ("now", now), ("tenant", m.TenantId), ("id", m.CompanyId), ("version", version));
            await Sql.Execute(c, t, "UPDATE tenants SET name=@name,updated_at=@now,row_version=row_version+1 WHERE id=@tenant", ct, ("name", edit.BusinessName), ("now", now), ("tenant", m.TenantId));
        }
        else await Sql.Execute(c, t, "UPDATE companies SET logo_key=@key,updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND id=@id AND row_version=@version", ct,
            ("key", logo), ("now", now), ("tenant", m.TenantId), ("id", m.CompanyId), ("version", version));
        await Audit(c, t, m, edit is null ? "BUSINESS_LOGO_CHANGED" : "BUSINESS_PROFILE_CHANGED", "COMPANY", m.CompanyId, "Business settings updated", now, correlation, ct);
        var updated = await Business(c, t, m, ct) ?? throw Forbidden();
        await t.CommitAsync(ct);
        return updated;
    }
    public Task<BusinessProfile> UpdateBusinessAsync(SessionData session, BusinessEdit edit, byte minorUnits, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct) =>
        EditBusiness(session, edit, minorUnits, null, edit.ExpectedVersion, now, policy, correlation, ct);
    public Task<BusinessProfile> SetLogoAsync(SessionData session, string key, ulong expectedVersion, DateTimeOffset now, AuthPolicy policy, string correlation, CancellationToken ct) =>
        EditBusiness(session, null, 0, key, expectedVersion, now, policy, correlation, ct);

    public async Task<ProvisionResult> ProvisionAsync(ProvisionBusiness input, string normalizedEmail, string initialHash, UserAccount? verifiedExisting, DateTimeOffset now, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var existing = await Sql.One(c, t, "SELECT * FROM users WHERE email_normalized=@email FOR UPDATE", ReadUser, ct, ("email", normalizedEmail));
        // Idempotent retries still require password proof in the application, and the full provisioning identity must agree.
        var replay = await Sql.One(c, t, """
            SELECT t.public_id,u.public_id AS user_public,m.id FROM tenants t JOIN companies c ON c.tenant_id=t.id
            JOIN tenant_memberships m ON m.tenant_id=t.id JOIN users u ON u.id=m.user_id
            WHERE t.provisioning_operation_id=@operation AND t.code=@code AND t.name=@name AND c.display_name=@display
            AND c.timezone=@timezone AND c.currency_code=@currency AND u.email_normalized=@email AND m.role='ADMINISTRATOR'
            """, r => new ProvisionResult(Sql.Guid(r, "public_id"), Sql.Guid(r, "user_public"), r.GetUInt64("id"), true), ct,
            ("operation", input.OperationId), ("code", input.TenantCode), ("name", input.BusinessName), ("display", input.DisplayName),
            ("timezone", input.Timezone), ("currency", input.CurrencyCode), ("email", normalizedEmail));
        if (replay is not null) { await t.CommitAsync(ct); return replay; }
        if (existing is not null && (verifiedExisting is null || existing.Id != verifiedExisting.Id || existing.SecurityStamp != verifiedExisting.SecurityStamp
            || existing.PasswordHash != verifiedExisting.PasswordHash || !existing.IsEnabled || existing.MustChangePassword || existing.LockoutUntil > now))
            throw new AppFailure(409, "PROVISIONING_CONFLICT", "The verified identity is unavailable.");
        try
        {
            var tenantPublic = Guid.NewGuid();
            await Sql.Execute(c, t, "INSERT INTO tenants(public_id,provisioning_operation_id,code,name,created_at,updated_at) VALUES(@public,@operation,@code,@name,@now,@now)", ct,
                ("public", tenantPublic), ("operation", input.OperationId), ("code", input.TenantCode), ("name", input.BusinessName), ("now", now));
            var tenant = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
            await Sql.Execute(c, t, "INSERT INTO companies(tenant_id,business_name,display_name,timezone,currency_code,currency_minor_units,created_at,updated_at) VALUES(@tenant,@name,@display,@timezone,@currency,@minor,@now,@now)", ct,
                ("tenant", tenant), ("name", input.BusinessName), ("display", input.DisplayName), ("timezone", input.Timezone), ("currency", input.CurrencyCode), ("minor", input.CurrencyMinorUnits), ("now", now));
            var company = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
            var user = existing;
            if (user is null)
            {
                var publicId = Guid.NewGuid();
                var stamp = Guid.NewGuid();
                await Sql.Execute(c, t, "INSERT INTO users(public_id,email_normalized,display_name,password_hash,security_stamp,created_at,updated_at) VALUES(@public,@email,@display,@hash,@stamp,@now,@now)", ct,
                    ("public", publicId), ("email", normalizedEmail), ("display", input.AdministratorName), ("hash", initialHash), ("stamp", stamp), ("now", now));
                user = new(Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct)), publicId, normalizedEmail, input.AdministratorName, initialHash, stamp, true, true, 0, null, 1);
            }
            await Sql.Execute(c, t, "INSERT INTO tenant_memberships(tenant_id,user_id,role,created_at,updated_at) VALUES(@tenant,@user,'ADMINISTRATOR',@now,@now)", ct,
                ("tenant", tenant), ("user", user.Id), ("now", now));
            var member = Convert.ToUInt64(await Sql.Scalar(c, t, "SELECT LAST_INSERT_ID()", ct));
            var m = new Membership(member, tenant, company, input.DisplayName, MembershipRoles.Administrator);
            foreach (var (action, entity, id) in new[] { ("TENANT_PROVISIONED", "TENANT", tenant), ("DEFAULT_COMPANY_CREATED", "COMPANY", company), ("ADMINISTRATOR_ASSIGNED", "MEMBERSHIP", member) })
                await Audit(c, t, m, action, entity, id, input.Reason, now, input.OperationId.ToString(), ct, input.OperatorReference);
            if (organization.Enabled) await OrganizationStore.EnsureTransit(c, t, tenant, company, now, input.OperationId.ToString(), input.OperatorReference, ct);
            await Security(c, t, user.Id, "BUSINESS_PROVISIONED", now, input.OperationId.ToString(), ct, input.OperatorReference);
            await t.CommitAsync(ct);
            return new(tenantPublic, user.PublicId, member, false);
        }
        catch (MySqlException e) when (e.Number == 1062) { throw new AppFailure(409, "PROVISIONING_CONFLICT", "The tenant or identity already exists. Verify the provisioning operation."); }
    }
    public async Task RecoverAsync(Guid publicUserId, string? passwordHash, bool disable, string operatorReference, string reason, DateTimeOffset now, CancellationToken ct)
    {
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var user = await Sql.One(c, t, "SELECT * FROM users WHERE public_id=@public FOR UPDATE", ReadUser, ct, ("public", publicUserId)) ?? throw Unauthorized();
        await Sql.Execute(c, t, "UPDATE users SET password_hash=@hash,security_stamp=@stamp,is_enabled=@enabled,must_change_password=TRUE,failed_access_count=0,lockout_until=NULL,updated_at=@now,row_version=row_version+1 WHERE id=@id", ct,
            ("hash", passwordHash ?? user.PasswordHash), ("stamp", Guid.NewGuid()), ("enabled", !disable), ("now", now), ("id", user.Id));
        await RevokeAll(c, t, user.Id, now, disable ? "ACCOUNT_DISABLED" : "RECOVERY", ct);
        await Security(c, t, user.Id, disable ? "ACCOUNT_DISABLED" : "CONTROLLED_RECOVERY", now, Guid.NewGuid().ToString(), ct, operatorReference);
        foreach (var m in await Memberships(c, t, user.Id, true, ct))
            await Audit(c, t, m, disable ? "IDENTITY_DISABLED" : "IDENTITY_RECOVERED", "USER", user.Id, reason, now, publicUserId.ToString(), ct, operatorReference);
        await t.CommitAsync(ct);
    }
    public async Task DisableMembershipAsync(ulong tenantId, ulong membershipId, string operatorReference, string reason, DateTimeOffset now, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(operatorReference) || operatorReference.Length > 100 || string.IsNullOrWhiteSpace(reason) || reason.Length > 300)
            throw new AppFailure(400, "OPERATOR_REQUIRED", "Verified operator and reason are required.");
        await using var c = await database.OpenAsync(ct);
        await using var t = await c.BeginTransactionAsync(ct);
        var target = await Sql.One(c, t, "SELECT m.id,m.tenant_id,c.id AS company_id,c.display_name,m.role FROM tenant_memberships m JOIN companies c ON c.tenant_id=m.tenant_id WHERE m.tenant_id=@tenant AND m.id=@id FOR UPDATE",
            r => new Membership(r.GetUInt64("id"), r.GetUInt64("tenant_id"), r.GetUInt64("company_id"), r.GetString("display_name"), r.GetString("role")), ct,
            ("tenant", tenantId), ("id", membershipId)) ?? throw Forbidden();
        await Sql.Execute(c, t, "UPDATE tenant_memberships SET status='DISABLED',updated_at=@now,row_version=row_version+1 WHERE tenant_id=@tenant AND id=@id", ct,
            ("now", now), ("tenant", tenantId), ("id", membershipId));
        await Audit(c, t, target, "MEMBERSHIP_DISABLED", "MEMBERSHIP", membershipId, reason, now, Guid.NewGuid().ToString(), ct, operatorReference);
        await t.CommitAsync(ct);
    }
}

using Conex360.Application.Identity;
using Conex360.Application.Organization;
using Conex360.Domain.Identity;
using Conex360.Infrastructure.Identity;
using Microsoft.Extensions.DependencyInjection;
using MySqlConnector;

namespace Conex360.IntegrationTests;

public sealed partial class MySqlIdentityTests
{
    [MySqlFact]
    public async Task OrganizationManagementIntegrityAndPermissions()
    {
        var settings = f.App.Services.GetRequiredService<OrganizationSettings>(); settings.Enabled = true;
        try
        {
            var store = f.App.Services.GetRequiredService<IOrganizationStore>();
            var concrete = (OrganizationStore)store;
            await Task.WhenAll(Enumerable.Range(0, 2).Select(_ => concrete.InitializeTransitAsync(f.A.TenantPublicId, "synthetic-tests", "Concurrent transit init", default)));
            var owner = await f.Login(); var admin = owner.Data; var tenant = admin.Selected!.TenantId; var company = admin.Selected.CompanyId;
            Assert.Equal(1UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM warehouses WHERE tenant_id=@tenant AND kind='TRANSIT'", ("tenant", tenant))));
            Assert.Equal(1UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM locations WHERE tenant_id=@tenant AND kind='TRANSIT'", ("tenant", tenant))));
            var outlet = await store.SaveOutletAsync(admin, null, new("FACTORY", "Synthetic Factory", null, null, null, true, 0, "Create fixture outlet"), "test", default);
            var second = await store.SaveOutletAsync(admin, null, new("SHOP", "Synthetic Shop", null, null, null, true, 0, "Create fixture outlet"), "test", default);
            var warehouses = await store.WarehousesAsync(admin, outlet.Id, default); var main = Assert.Single(warehouses); Assert.True(main.IsDefault);
            var locations = await store.LocationsAsync(admin, main.Id, default); Assert.Equal(new[] { "DAMAGED", "HOLD", "STORAGE" }, locations.Select(x => x.Kind));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveOutletAsync(admin, null, new("FACTORY", "Duplicate", null, null, null, true, 0, "Duplicate test"), "test", default));
            var auditBefore = Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", tenant)));
            var branchBefore = Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM branches WHERE tenant_id=@tenant", ("tenant", tenant)));
            await store.SaveWarehouseAsync(admin, null, new(outlet.Id, "ROLLBACK-MAIN", "Existing collision", null, true, false, null, 0, "Rollback fixture"), "test", default);
            auditBefore++;
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveOutletAsync(admin, null, new("ROLLBACK", "Must roll back", null, null, null, true, 0, "Atomic rollback"), "test", default));
            Assert.Equal(branchBefore, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM branches WHERE tenant_id=@tenant", ("tenant", tenant))));
            Assert.Equal(auditBefore, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant", ("tenant", tenant))));
            var edit = new OutletEdit(outlet.Code, "Factory revised", null, null, null, true, outlet.Version, "Concurrent edit");
            var outcomes = await Task.WhenAll(Enumerable.Range(0, 2).Select(async _ => { try { await store.SaveOutletAsync(admin, outlet.Id, edit, "test", default); return true; } catch (AppFailure e) when (e.Code == "VERSION_CONFLICT") { return false; } })); Assert.Single(outcomes, x => x);
            var packing = await store.SaveWarehouseAsync(admin, null, new(outlet.Id, "PACKAGING", "Packaging", null, true, false, null, 0, "Add packaging storage"), "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveWarehouseAsync(admin, main.Id, new(outlet.Id, main.Code, main.Name, null, false, false, null, main.Version, "Unsafe default removal"), "test", default));
            await store.SaveWarehouseAsync(admin, main.Id, new(outlet.Id, main.Code, "Old main", null, false, false, packing.Id, main.Version, "Replace default"), "test", default);
            Assert.Equal(packing.Id, Assert.Single(await store.WarehousesAsync(admin, outlet.Id, default), x => x.IsDefault).Id);
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE warehouses SET is_default=1 WHERE id=@id", ("id", main.Id)));
            var transit = Convert.ToUInt64(await f.Sql("SELECT id FROM warehouses WHERE tenant_id=@tenant AND kind='TRANSIT'", ("tenant", tenant)));
            Assert.DoesNotContain(await store.WarehousesAsync(admin, null, default), w => w.Id == transit);
            await Assert.ThrowsAsync<AppFailure>(() => store.LocationsAsync(admin, transit, default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveWarehouseAsync(admin, transit, new(outlet.Id, "TRANSIT-EDIT", "Forbidden", null, true, false, null, 1, "Forbidden transit"), "test", default));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE warehouses SET is_active=0 WHERE id=@id", ("id", transit)));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("INSERT INTO locations(tenant_id,company_id,warehouse_id,warehouse_kind,code,name,kind,created_at,updated_at) VALUES(@tenant,@company,@id,'ORDINARY','BAD','Bad','TRANSIT',UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))", ("tenant", tenant), ("company", company), ("id", packing.Id)));
            var independent = Convert.ToUInt64(await f.Sql("SELECT tenant_id FROM tenant_memberships WHERE id=@id", ("id", f.B.MembershipId)));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("INSERT INTO warehouses(tenant_id,company_id,branch_id,code,name,kind,created_at,updated_at) VALUES(@tenant,@company,@branch,'FOREIGN','Foreign','ORDINARY',UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))", ("tenant", independent), ("company", company), ("branch", outlet.Id)));
            await Assert.ThrowsAsync<MySqlException>(() => f.Sql("DELETE FROM branches WHERE id=0"));
            var staff = await store.CreateStaffAsync(admin, new(Guid.NewGuid().ToString("N") + "@example.invalid", "Synthetic Staff", [outlet.Id], "Create staff"), "test", default);
            var failedEmail = Guid.NewGuid().ToString("N") + "@example.invalid";
            await Assert.ThrowsAsync<AppFailure>(() => store.CreateStaffAsync(admin, new(failedEmail, "Must roll back", [ulong.MaxValue], "Reject foreign grant"), "test", default));
            Assert.Equal(0UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM users WHERE email_normalized=@email", ("email", failedEmail.ToUpperInvariant()))));
            var issued = await f.Service.LoginAsync(staff.Email, staff.TemporaryPassword, "test", default); Assert.True(issued.Data.User.MustChangePassword);
            var changed = await f.Service.ChangePasswordAsync(issued.Data, staff.TemporaryPassword, SessionSecrets.Create(), "test", default);
            Assert.Single(await store.OutletsAsync(changed.Data, default));
            Assert.DoesNotContain(await store.WarehousesAsync(changed.Data, null, default), w => w.BranchId == second.Id);
            await Assert.ThrowsAsync<AppFailure>(() => store.WarehousesAsync(changed.Data, second.Id, default));
            await Assert.ThrowsAsync<AppFailure>(() => store.SaveOutletAsync(changed.Data, null, edit, "test", default));
            await Assert.ThrowsAsync<AppFailure>(() => store.UsersAsync(changed.Data, default));
            await Assert.ThrowsAsync<AppFailure>(() => store.CreateStaffAsync(admin, new(f.Email, "Existing identity", [], "Reject email linking"), "test", default));
            var selected = await store.SelectOutletAsync(changed.Data, outlet.Id, "test", default);
            Assert.Equal(outlet.Id, selected.SelectedBranchId);
            var beforeRevocation = await f.Service.ValidateSessionAsync(changed.Secret, default); Assert.NotNull(beforeRevocation);
            var row = (await store.UsersAsync(admin, default)).Single(m => m.MembershipId == staff.MembershipId);
            await store.UpdateMemberAsync(admin, row.MembershipId, new("STAFF", true, [], row.Version, "Revoke grant"), "test", default);
            await Assert.ThrowsAsync<AppFailure>(() => store.WarehousesAsync(beforeRevocation, null, default));
            var fresh = await f.Service.ValidateSessionAsync(changed.Secret, default); Assert.NotNull(fresh); Assert.Null(fresh.Session.SelectedBranchId); Assert.Empty(await store.OutletsAsync(fresh, default));
            var own = (await store.UsersAsync(admin, default)).Single(m => m.MembershipId == f.A.MembershipId);
            await Assert.ThrowsAsync<AppFailure>(() => store.UpdateMemberAsync(admin, own.MembershipId, new("STAFF", true, [], own.Version, "Reject last admin demotion"), "test", default));
            row = (await store.UsersAsync(admin, default)).Single(m => m.MembershipId == staff.MembershipId);
            await store.UpdateMemberAsync(admin, row.MembershipId, new("ADMINISTRATOR", true, [], row.Version, "Promote second admin"), "test", default);
            var secondAdmin = await f.Service.ValidateSessionAsync(changed.Secret, default); Assert.NotNull(secondAdmin);
            row = (await store.UsersAsync(admin, default)).Single(m => m.MembershipId == staff.MembershipId);
            var attempts = await Task.WhenAll(new[] { (Session: admin, Member: own.MembershipId, Version: own.Version), (Session: secondAdmin, Member: row.MembershipId, Version: row.Version) }.Select(async a =>
            {
                try { await store.UpdateMemberAsync(a.Session, a.Member, new(a.Member == own.MembershipId ? "STAFF" : "ADMINISTRATOR", a.Member == own.MembershipId, [], a.Version, "Concurrent demotion/deactivation protection"), "test", default); return true; }
                catch (Exception e) when (e is AppFailure or MySqlException) { return false; }
            })); Assert.Single(attempts, x => x);
            Assert.Equal(1UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM tenant_memberships m JOIN users u ON u.id=m.user_id WHERE m.tenant_id=@tenant AND m.role='ADMINISTRATOR' AND m.status='ACTIVE' AND u.is_enabled=1", ("tenant", tenant))));
            // Restore synthetic memberships for the pre-existing fixture tests only.
            await f.Sql("UPDATE tenant_memberships SET role='ADMINISTRATOR',row_version=row_version+1 WHERE id=@id", ("id", own.MembershipId));
            admin = (await f.Login()).Data;
            var current = (await store.OutletsAsync(admin, default)).Single(b => b.Id == outlet.Id);
            await store.SaveOutletAsync(admin, current.Id, new(current.Code, current.Name, null, null, null, false, current.Version, "Controlled outlet deactivation"), "test", default);
            admin = (await f.Service.ValidateSessionAsync((await f.Login()).Secret, default))!;
            Assert.All(await store.WarehousesAsync(admin, outlet.Id, default), w => Assert.False(w.IsActive));
            var link = new LinkExistingMembership(f.B.TenantPublicId, f.A.UserPublicId, f.Email, "STAFF", "synthetic-tests", "Verified owner consent fixture");
            await Assert.ThrowsAsync<AppFailure>(() => concrete.LinkExistingAsync(link, "incorrect proof", default));
            await concrete.LinkExistingAsync(link, f.Password, default);
            var sharedLogin = await f.Service.LoginAsync(f.Email, f.Password, "link-test", default);
            var linked = sharedLogin.Data.Memberships.Single(m => m.TenantId == independent);
            var linkedSession = await f.Service.SelectAsync(sharedLogin.Data, linked.Id, "link-test", default);
            Assert.Empty(await store.OutletsAsync(linkedSession, default));
            using var http = await f.Client();
            Assert.Equal(System.Net.HttpStatusCode.NotFound, (await http.GetAsync("/api/v1/organization/warehouses/" + transit + "/locations")).StatusCode);
        }
        finally { settings.Enabled = false; }
    }
}

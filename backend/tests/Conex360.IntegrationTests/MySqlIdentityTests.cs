using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Conex360.Application.Identity;
using Conex360.Domain.Identity;
using Conex360.Infrastructure.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MySqlConnector;
using SkiaSharp;

namespace Conex360.IntegrationTests;

public sealed class MySqlFactAttribute : FactAttribute
{
    public MySqlFactAttribute() { if (Environment.GetEnvironmentVariable("CONEX360_MYSQL_APPROVED") != "1") Skip = "Requires separately approved isolated MySQL target."; }
}
public sealed class MySqlFixture : IAsyncLifetime
{
    public sealed class Factory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder) => builder.UseContentRoot(Path.GetFullPath("../../../../../src/Conex360.Api", AppContext.BaseDirectory)).UseEnvironment("Development").ConfigureAppConfiguration((_, c) =>
            c.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Authentication:Enabled"] = "true",
                ["Authentication:AllowInsecureDevelopmentCookies"] = "true",
                ["Authentication:AllowedOrigins:0"] = "http://localhost",
                ["Database:Enabled"] = "true",
                ["Database:ConnectionFile"] = Environment.GetEnvironmentVariable("Database__ConnectionFile"),
                ["Storage:KeyDirectory"] = "/evidence/test-keys",
                ["Storage:LogoDirectory"] = "/evidence/test-logos",
                ["Storage:CertificateFile"] = "/run/secrets/dp_certificate",
                ["Storage:CertificatePasswordFile"] = "/run/secrets/dp_password"
            })).ConfigureServices(s => IdentityTestHost.Configure(s, true));
    }
    public Factory App { get; } = new();
    public IdentityService Service => App.Services.GetRequiredService<IdentityService>();
    public IIdentityStore Store => App.Services.GetRequiredService<IIdentityStore>();
    public AuthPolicy Policy => App.Services.GetRequiredService<AuthPolicy>();
    public string Email { get; } = Guid.NewGuid().ToString("N") + "@example.invalid";
    public string Password { get; } = SessionSecrets.Create();
    public ProvisionBusiness Input { get; private set; } = null!;
    public ProvisionResult A { get; private set; } = null!;
    public ProvisionResult B { get; private set; } = null!;
    public ProvisionResult Shared { get; private set; } = null!;
    public ProvisionBusiness NewInput(string email) => new(Guid.NewGuid(), "synthetic-" + Guid.NewGuid().ToString("N"), "Synthetic Coconut Works", "Coconut Works", email, "Synthetic Operator", "Asia/Colombo", "LKR", 2, "synthetic-tests", "Isolated P1-02 acceptance test");
    public async Task InitializeAsync()
    {
        if (Environment.GetEnvironmentVariable("CONEX360_MYSQL_APPROVED") != "1") return;
        var database = App.Services.GetRequiredService<Database>();
        await using (var c = await database.OpenAsync(default))
            if (c.Database != "conex360_auth_review") throw new InvalidOperationException("Synthetic tests may only use the approved review database.");
        Input = NewInput(Email);
        var temporary = SessionSecrets.Create();
        A = await Service.ProvisionAsync(Input, temporary, false, default);
        var initial = await Service.LoginAsync(Email, temporary, "fixture", default);
        await Service.ChangePasswordAsync(initial.Data, temporary, Password, "fixture", default);
        B = await Service.ProvisionAsync(NewInput(Guid.NewGuid().ToString("N") + "@example.invalid"), SessionSecrets.Create(), false, default);
        Shared = await Service.ProvisionAsync(NewInput(Email), Password, true, default);
        Directory.CreateDirectory("/evidence");
        await File.WriteAllTextAsync("/evidence/browser-fixture.json", JsonSerializer.Serialize(new { email = Email, password = Password, membershipId = A.MembershipId.ToString(), sharedMembershipId = Shared.MembershipId.ToString(), businessName = Input.DisplayName }));
    }
    public async Task DisposeAsync() => await App.DisposeAsync();
    public async Task<IssuedSession> Login(ulong? membership = null)
    {
        var s = await Service.LoginAsync(Email, Password, "test", default);
        return s with { Data = await Service.SelectAsync(s.Data, membership ?? A.MembershipId, "test", default) };
    }
    public async Task<HttpClient> Client()
    {
        var c = App.CreateClient(new WebApplicationFactoryClientOptions { AllowAutoRedirect = false });
        var response = await Send(c, HttpMethod.Post, "/api/v1/auth/login", new { email = Email, password = Password });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var s = await response.Content.ReadFromJsonAsync<JsonElement>();
        var selected = await Send(c, HttpMethod.Post, "/api/v1/auth/context", new { membershipId = A.MembershipId.ToString(), expectedContextVersion = s.GetProperty("contextVersion").GetString() });
        var result = await selected.Content.ReadFromJsonAsync<JsonElement>();
        c.DefaultRequestHeaders.Add("X-Conex360-Context", result.GetProperty("contextVersion").GetString());
        return c;
    }
    public static async Task<HttpResponseMessage> Send(HttpClient c, HttpMethod method, string path, object? input = null, bool csrf = true)
    {
        var request = new HttpRequestMessage(method, path);
        if (csrf)
        {
            var token = (await c.GetFromJsonAsync<JsonElement>("/api/v1/auth/csrf")).GetProperty("token").GetString();
            request.Headers.Add("X-CSRF-TOKEN", token);
        }
        if (input is not null) request.Content = JsonContent.Create(input);
        return await c.SendAsync(request);
    }
    public async Task<object?> Sql(string sql, params (string, object?)[] parameters)
    {
        await using var c = await App.Services.GetRequiredService<Database>().OpenAsync(default);
        await using var cmd = new MySqlCommand(sql, c);
        foreach (var (key, value) in parameters) cmd.Parameters.AddWithValue(key, value ?? DBNull.Value);
        return await cmd.ExecuteScalarAsync();
    }
}

public sealed partial class MySqlIdentityTests(MySqlFixture f) : IClassFixture<MySqlFixture>
{
    [MySqlFact]
    public async Task RuntimeCannotAlterJournalOrEvidenceAndSuspensionPreservesOtherMemberships()
    {
        await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE schema_migrations SET name='forbidden' WHERE version='missing'"));
        await Assert.ThrowsAsync<MySqlException>(() => f.Sql("DELETE FROM audit_events WHERE id=0"));
        await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE security_events SET event_code='forbidden' WHERE id=0"));
        var issued = await f.Login(); var tenant = issued.Data.Selected!.TenantId;
        await f.Sql("UPDATE tenants SET status='SUSPENDED',row_version=row_version+1 WHERE id=@id", ("id", tenant));
        try
        {
            var active = await f.Service.ValidateSessionAsync(issued.Secret, default);
            Assert.NotNull(active); Assert.Null(active.Selected);
            await Assert.ThrowsAsync<AppFailure>(() => f.Service.BusinessAsync(issued.Data, default));
            var other = await f.Service.SelectAsync(active, f.Shared.MembershipId, "suspension-test", default);
            Assert.NotEqual(tenant, (await f.Service.BusinessAsync(other, default)).TenantId);
        }
        finally { await f.Sql("UPDATE tenants SET status='ACTIVE',row_version=row_version+1 WHERE id=@id", ("id", tenant)); }
    }
    [MySqlFact]
    public async Task ProvisioningIsAtomicReplaySafeAndOneCompanyIsEnforced()
    {
        var replay = await f.Service.ProvisionAsync(f.Input, f.Password, false, default);
        Assert.True(replay.Replayed); Assert.Equal(f.A.TenantPublicId, replay.TenantPublicId);
        await Assert.ThrowsAsync<AppFailure>(() => f.Service.ProvisionAsync(f.Input with { OperationId = Guid.NewGuid() }, f.Password, false, default));
        var broken = f.NewInput(Guid.NewGuid().ToString("N") + "@example.invalid") with { CurrencyMinorUnits = 7 };
        var hash = f.App.Services.GetRequiredService<IPasswordService>().Hash(broken.AdministratorEmail, SessionSecrets.Create());
        await Assert.ThrowsAsync<MySqlException>(() => f.Store.ProvisionAsync(broken, broken.AdministratorEmail.ToUpperInvariant(), hash, null, DateTimeOffset.UtcNow, default));
        Assert.Equal(0UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM tenants WHERE code=@code", ("code", broken.TenantCode))));
        var s = await f.Login(); var m = s.Data.Selected!;
        await Assert.ThrowsAsync<MySqlException>(() => f.Sql("INSERT INTO companies(tenant_id,business_name,display_name,timezone,currency_code,currency_minor_units,created_at,updated_at) VALUES(@tenant,'Duplicate','Duplicate','UTC','LKR',2,UTC_TIMESTAMP(6),UTC_TIMESTAMP(6))", ("tenant", m.TenantId)));
        Assert.Equal(3UL, Convert.ToUInt64(await f.Sql("SELECT COUNT(*) FROM audit_events WHERE tenant_id=@tenant AND action IN ('TENANT_PROVISIONED','DEFAULT_COMPANY_CREATED','ADMINISTRATOR_ASSIGNED')", ("tenant", m.TenantId))));
    }
    [MySqlFact]
    public async Task HttpLoginCsrfLogoutAndCookieReplayRevocation()
    {
        using var c = await f.Client();
        Assert.Equal(HttpStatusCode.OK, (await c.GetAsync("/api/v1/business/")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await MySqlFixture.Send(c, HttpMethod.Post, "/api/v1/auth/logout", csrf: false)).StatusCode);
        var cookie = c.DefaultRequestHeaders.Contains("Cookie"); // CookieContainer is maintained by the real test host handler.
        Assert.False(cookie);
        Assert.Equal(HttpStatusCode.NoContent, (await MySqlFixture.Send(c, HttpMethod.Post, "/api/v1/auth/logout")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await c.GetAsync("/api/v1/auth/session")).StatusCode);
        var issued = await f.Login(); await f.Service.LogoutAsync(issued.Data, "test", default);
        Assert.Null(await f.Service.ValidateSessionAsync(issued.Secret, default));
    }
    [MySqlFact]
    public async Task ForcedPasswordChangeRotatesSessionsAndRecoveryDisablesGlobally()
    {
        var input = f.NewInput(Guid.NewGuid().ToString("N") + "@example.invalid"); var temporary = SessionSecrets.Create();
        var user = await f.Service.ProvisionAsync(input, temporary, false, default);
        using var c = f.App.CreateClient();
        var login = await MySqlFixture.Send(c, HttpMethod.Post, "/api/v1/auth/login", new { email = input.AdministratorEmail, password = temporary });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        c.DefaultRequestHeaders.Add("X-Conex360-Context", "1");
        Assert.Equal(HttpStatusCode.Forbidden, (await c.GetAsync("/api/v1/business/")).StatusCode);
        var other = await f.Service.LoginAsync(input.AdministratorEmail, temporary, "test", default);
        var changed = await MySqlFixture.Send(c, HttpMethod.Post, "/api/v1/auth/password", new { currentPassword = temporary, newPassword = SessionSecrets.Create() });
        Assert.Equal(HttpStatusCode.OK, changed.StatusCode);
        Assert.Null(await f.Service.ValidateSessionAsync(other.Secret, default));
        Assert.Equal(HttpStatusCode.OK, (await c.GetAsync("/api/v1/business/")).StatusCode);
        var recoveryPassword = SessionSecrets.Create();
        await Assert.ThrowsAsync<AppFailure>(() => f.Service.RecoverAsync(Guid.NewGuid(), input.AdministratorEmail, recoveryPassword, false, "synthetic-tests", "Reject mismatched identity", default));
        await f.Service.RecoverAsync(user.UserPublicId, input.AdministratorEmail, recoveryPassword, false, "synthetic-tests", "Verified controlled recovery", default);
        Assert.Equal(HttpStatusCode.Unauthorized, (await c.GetAsync("/api/v1/auth/session")).StatusCode);
        var recovered = await f.Service.LoginAsync(input.AdministratorEmail, recoveryPassword, "recovery-test", default);
        Assert.True(recovered.Data.User.MustChangePassword);
        await Assert.ThrowsAsync<AppFailure>(() => f.Service.BusinessAsync(recovered.Data, default));
        await f.Service.RecoverAsync(user.UserPublicId, input.AdministratorEmail, null, true, "synthetic-tests", "Disable test identity", default);
        Assert.Equal(HttpStatusCode.Unauthorized, (await c.GetAsync("/api/v1/auth/session")).StatusCode);
        Assert.Null(await f.Service.ValidateSessionAsync(recovered.Secret, default));
        var disabled = await Assert.ThrowsAsync<AppFailure>(() => f.Service.LoginAsync(input.AdministratorEmail, recoveryPassword, "test", default));
        var unknown = await Assert.ThrowsAsync<AppFailure>(() => f.Service.LoginAsync("unknown@example.invalid", temporary, "test", default));
        Assert.Equal(unknown.Message, disabled.Message);
    }
    [MySqlFact]
    public async Task ContextSelectionRejectsForeignMembershipAndStaleTab()
    {
        var issued = await f.Login();
        await Assert.ThrowsAsync<AppFailure>(() => f.Service.SelectAsync(issued.Data, f.B.MembershipId, "test", default));
        var switched = await f.Service.SelectAsync(issued.Data, f.Shared.MembershipId, "test", default);
        var stale = await Assert.ThrowsAsync<AppFailure>(() => f.Service.BusinessAsync(issued.Data, default));
        Assert.Equal("CONTEXT_CHANGED", stale.Code);
        var b = await f.Service.BusinessAsync(switched, default);
        Assert.Equal(switched.Selected!.TenantId, b.TenantId);
        await f.Store.DisableMembershipAsync(switched.Selected.TenantId, switched.Selected.Id, "synthetic-tests", "Membership isolation test", DateTimeOffset.UtcNow, default);
        var refreshed = await f.Service.ValidateSessionAsync(issued.Secret, default);
        Assert.NotNull(refreshed); Assert.Null(refreshed.Selected);
        Assert.Contains(refreshed.Memberships, m => m.Id == f.A.MembershipId);
        // Restore only the synthetic membership so independent tests remain deterministic; global identity/session was untouched.
        await f.Sql("UPDATE tenant_memberships SET status='ACTIVE',row_version=row_version+1 WHERE id=@id", ("id", f.Shared.MembershipId));
    }
    [MySqlFact]
    public async Task StaffCannotEditOrUploadAndOptimisticEditsAllowOnlyOneWinner()
    {
        var issued = await f.Login(); var s = issued.Data; var m = s.Selected!;
        var old = await f.Service.BusinessAsync(s, default);
        var edit = new BusinessEdit(old.BusinessName, old.DisplayName, null, null, null, old.Timezone, old.CurrencyCode, old.Version);
        var tasks = Enumerable.Range(0, 2).Select(async _ => { try { await f.Service.UpdateBusinessAsync(s, edit, "test", default); return true; } catch (AppFailure e) when (e.Code == "VERSION_CONFLICT") { return false; } });
        Assert.Single(await Task.WhenAll(tasks), x => x);
        await f.Sql("UPDATE tenant_memberships SET role='STAFF',row_version=row_version+1 WHERE id=@id", ("id", m.Id));
        try
        {
            using var c = await f.Client();
            Assert.Equal(HttpStatusCode.OK, (await c.GetAsync("/api/v1/business/")).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await MySqlFixture.Send(c, HttpMethod.Put, "/api/v1/business/", edit)).StatusCode);
            Assert.Equal(HttpStatusCode.Forbidden, (await MySqlFixture.Send(c, HttpMethod.Post, "/api/v1/business/logo")).StatusCode);
        }
        finally { await f.Sql("UPDATE tenant_memberships SET role='ADMINISTRATOR',row_version=row_version+1 WHERE id=@id", ("id", m.Id)); }
    }
    [MySqlFact]
    public async Task LogoValidationScopedAccessCacheAndStoredFiles()
    {
        using var c = await f.Client();
        var profile = await c.GetFromJsonAsync<JsonElement>("/api/v1/business/");
        async Task<HttpResponseMessage> Upload(byte[] bytes)
        {
            var token = (await c.GetFromJsonAsync<JsonElement>("/api/v1/auth/csrf")).GetProperty("token").GetString();
            var req = new HttpRequestMessage(HttpMethod.Post, "/api/v1/business/logo") { Content = new ByteArrayContent(bytes) };
            req.Headers.Add("X-CSRF-TOKEN", token); req.Headers.Add("X-Conex360-Version", profile.GetProperty("version").GetString()); return await c.SendAsync(req);
        }
        Assert.Equal(HttpStatusCode.BadRequest, (await Upload("<svg onload='alert(1)'/>"u8.ToArray())).StatusCode);
        using var bitmap = new SKBitmap(32, 32); bitmap.Erase(SKColors.CornflowerBlue);
        using var image = SKImage.FromBitmap(bitmap); using var png = image.Encode(SKEncodedImageFormat.Png, 100);
        Assert.Equal(HttpStatusCode.OK, (await Upload(png.ToArray())).StatusCode);
        var context = c.DefaultRequestHeaders.GetValues("X-Conex360-Context").Single();
        var logo = await c.GetAsync("/api/v1/business/logo?context=" + context);
        Assert.Equal(HttpStatusCode.OK, logo.StatusCode); Assert.Equal("no-store", logo.Headers.CacheControl?.ToString()); Assert.Equal("image/png", logo.Content.Headers.ContentType?.MediaType);
        using var anonymous = f.App.CreateClient(); Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/v1/business/logo?context=" + context)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await c.GetAsync("/api/v1/business/logo?context=999")).StatusCode);
        var updated = await f.Service.BusinessAsync((await f.Login()).Data, default);
        var files = f.App.Services.GetRequiredService<ILogoStore>();
        Assert.NotEmpty((await files.ReadAsync(updated.TenantId, updated.Id, updated.LogoKey!, default))!);
        Assert.Null(await files.ReadAsync(updated.TenantId + 99999, updated.Id, updated.LogoKey!, default));
    }
    [MySqlFact]
    public async Task ExpiredSessionLockoutAndReadinessUseRealMySql()
    {
        var issued = await f.Login();
        var now = DateTimeOffset.UtcNow; var secret = SessionSecrets.Create(); var user = issued.Data.User;
        var idle = new SessionRecord(Guid.NewGuid(), SessionSecrets.Hash(secret), user.Id, user.SecurityStamp, f.A.MembershipId, 1, now.AddMinutes(-32), now.AddMinutes(-32), now.AddHours(1), null);
        await f.Store.CommitLoginAsync(new(user, true, null, idle, now.AddMinutes(-32), "expiry-test"), f.Policy, default);
        Assert.Null(await f.Service.ValidateSessionAsync(secret, default));
        var absoluteSecret = SessionSecrets.Create();
        await f.Store.CommitLoginAsync(new(user, true, null, idle with { PublicId = Guid.NewGuid(), KeyHash = SessionSecrets.Hash(absoluteSecret), CreatedAt = now.AddHours(-9), LastActivityAt = now.AddHours(-2), AbsoluteExpiresAt = now.AddHours(-1) }, now.AddHours(-9), "expiry-test"), f.Policy, default);
        Assert.Null(await f.Service.ValidateSessionAsync(absoluteSecret, default));
        await Assert.ThrowsAsync<MySqlException>(() => f.Sql("UPDATE auth_sessions SET created_at=DATE_SUB(created_at,INTERVAL 1 SECOND) WHERE public_id=@id", ("id", issued.Data.Session.PublicId.ToByteArray(true))));
        Assert.True(await f.App.Services.GetRequiredService<IDatabaseReadiness>().CheckAsync(default));
        var input = f.NewInput(Guid.NewGuid().ToString("N") + "@example.invalid"); var password = SessionSecrets.Create();
        await f.Service.ProvisionAsync(input, password, false, default);
        for (var i = 0; i < 5; i++) await Assert.ThrowsAsync<AppFailure>(() => f.Service.LoginAsync(input.AdministratorEmail, "wrong password", "lockout-test", default));
        var locked = await Assert.ThrowsAsync<AppFailure>(() => f.Service.LoginAsync(input.AdministratorEmail, password, "lockout-test", default));
        Assert.Equal(IdentityService.LoginMessage, locked.Message);
    }
}

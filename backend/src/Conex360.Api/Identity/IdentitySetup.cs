using System.Security.Claims;
using System.Security.Cryptography.X509Certificates;
using System.Threading.RateLimiting;
using Conex360.Application.Catalog;
using Conex360.Application.Identity;
using Conex360.Application.Organization;
using Conex360.Domain.Identity;
using Conex360.Infrastructure.Identity;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;

namespace Conex360.Api.Identity;

public static class IdentitySetup
{
    public const string Scheme = "ConexSession";
    public static SessionData Session(HttpContext context) => (SessionData)context.Items[typeof(SessionData)]!;
    public static void AddConexIdentity(this WebApplicationBuilder builder) => builder.Host.ConfigureServices((context, services) => Register(context.Configuration, context.HostingEnvironment, services));
    private static void Register(IConfiguration configuration, IHostEnvironment environment, IServiceCollection services)
    {
        var policy = configuration.GetSection("Authentication").Get<AuthPolicy>() ?? new();
        var db = configuration.GetSection("Database").Get<DatabaseSettings>() ?? new();
        var storage = configuration.GetSection("Storage").Get<StorageSettings>() ?? new();
        var business = configuration.GetSection("Business").Get<BusinessPolicy>() ?? new();
        var organization = configuration.GetSection("Organization").Get<OrganizationSettings>() ?? new();
        var catalog = configuration.GetSection("Catalog").Get<CatalogSettings>() ?? new();
        db.MinimumSchemaVersion = catalog.Enabled ? 7 : organization.Enabled ? 5 : 2;
        var insecure = environment.IsDevelopment() && policy.AllowInsecureDevelopmentCookies;
        if (!environment.IsDevelopment() && db.AllowUnverifiedDevelopmentTls)
            throw new InvalidOperationException("Unverified database certificates are restricted to explicit local Development configuration.");
        if (policy.IdleMinutes is < 5 or > 120 || policy.AbsoluteHours is < 1 or > 24
            || policy.FailedAttempts is < 3 or > 10 || policy.LockoutMinutes is < 1 or > 60
            || policy.MinimumPasswordLength is < 15 or > 64 || policy.PasswordIterations < 210_000)
            throw new InvalidOperationException("Authentication policy is outside the supported safety limits.");
        if (policy.Enabled && (!db.Enabled || string.IsNullOrWhiteSpace(storage.KeyDirectory) || string.IsNullOrWhiteSpace(storage.LogoDirectory)
            || policy.AllowedOrigins.Length == 0 || policy.AllowedOrigins.Any(o => !Uri.TryCreate(o, UriKind.Absolute, out var uri)
                || uri.GetLeftPart(UriPartial.Authority) != o || (!insecure && uri.Scheme != "https"))))
            throw new InvalidOperationException("Authentication requires database, persistent storage and explicit secure origins.");
        if (!environment.IsDevelopment() && policy.AllowInsecureDevelopmentCookies)
            throw new InvalidOperationException("Insecure cookies are restricted to explicit local Development configuration.");
        services.AddSingleton(policy);
        services.AddSingleton(db);
        services.AddSingleton(storage);
        services.AddSingleton(business);
        services.AddSingleton(organization);
        services.AddSingleton(catalog);
        services.AddSingleton<ICatalogStore, CatalogStore>();
        services.AddSingleton<IOrganizationStore, OrganizationStore>();
        services.AddSingleton<Database>();
        services.AddSingleton<IDatabaseReadiness>(s => s.GetRequiredService<Database>());
        services.AddSingleton<IPasswordService, PasswordService>();
        services.AddSingleton<IIdentityStore, IdentityStore>();
        services.AddSingleton<ILogoStore, LogoStore>();
        services.AddSingleton<IdentityService>();
        services.AddSingleton<Migrations>();
        var protection = services.AddDataProtection().SetApplicationName("SysConex.Conex360.P1");
        if (policy.Enabled)
        {
            Directory.CreateDirectory(storage.KeyDirectory);
            protection.PersistKeysToFileSystem(new DirectoryInfo(storage.KeyDirectory));
            if (string.IsNullOrWhiteSpace(storage.CertificateFile) || string.IsNullOrWhiteSpace(storage.CertificatePasswordFile))
                throw new InvalidOperationException("Persistent Data Protection keys require an encryption certificate and password file.");
            var cert = X509CertificateLoader.LoadPkcs12FromFile(storage.CertificateFile,
                File.ReadAllText(storage.CertificatePasswordFile).Trim(), X509KeyStorageFlags.EphemeralKeySet);
            if (!cert.HasPrivateKey || cert.NotAfter.ToUniversalTime() <= DateTime.UtcNow)
                throw new InvalidOperationException("The Data Protection certificate must have a valid private key.");
            protection.ProtectKeysWithCertificate(cert);
        }
        services.AddAuthentication(Scheme).AddCookie(Scheme, options =>
        {
            options.Cookie.Name = insecure ? "Conex360.Dev.Session" : "__Host-Conex360.Session";
            options.Cookie.HttpOnly = true;
            options.Cookie.Path = "/";
            options.Cookie.SameSite = SameSiteMode.Lax;
            options.Cookie.SecurePolicy = insecure ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
            options.SlidingExpiration = false;
            options.ExpireTimeSpan = TimeSpan.FromHours(policy.AbsoluteHours);
            options.Events = new CookieAuthenticationEvents
            {
                OnRedirectToLogin = c => { c.Response.StatusCode = 401; return Task.CompletedTask; },
                OnRedirectToAccessDenied = c => { c.Response.StatusCode = 403; return Task.CompletedTask; },
                OnValidatePrincipal = async c =>
                {
                    var secret = c.Principal?.FindFirstValue(ClaimTypes.NameIdentifier) ?? "";
                    var session = c.HttpContext.RequestServices.GetRequiredService<AuthPolicy>().Enabled ? await c.HttpContext.RequestServices.GetRequiredService<IdentityService>()
                        .ValidateSessionAsync(secret, c.HttpContext.RequestAborted) : null;
                    if (session is null) { c.RejectPrincipal(); await c.HttpContext.SignOutAsync(Scheme); }
                    else c.HttpContext.Items[typeof(SessionData)] = session;
                }
            };
        });
        services.AddAuthorization(options =>
        {
            options.FallbackPolicy = new AuthorizationPolicyBuilder(Scheme).RequireAuthenticatedUser().Build();
            options.AddPolicy("Business", p => p.RequireAuthenticatedUser().RequireAssertion(c => c.Resource is HttpContext h
                && h.Items[typeof(SessionData)] is SessionData s && !s.User.MustChangePassword && s.Selected is not null));
            options.AddPolicy("Administrator", p => p.RequireAuthenticatedUser().RequireAssertion(c => c.Resource is HttpContext h
                && h.Items[typeof(SessionData)] is SessionData s && !s.User.MustChangePassword && s.Selected?.Role == MembershipRoles.Administrator));
        });
        services.AddAntiforgery(options =>
        {
            options.HeaderName = "X-CSRF-TOKEN";
            options.Cookie.Name = insecure ? "Conex360.Dev.Csrf" : "__Host-Conex360.Csrf";
            options.Cookie.HttpOnly = true;
            options.Cookie.SecurePolicy = insecure ? CookieSecurePolicy.SameAsRequest : CookieSecurePolicy.Always;
            options.Cookie.SameSite = SameSiteMode.Strict;
            options.Cookie.Path = "/";
        });
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = 429;
            // Remote IP comes from the trusted proxy connection, never an arbitrary forwarded header.
            options.AddPolicy("login", c => RateLimitPartition.GetFixedWindowLimiter(c.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions { PermitLimit = 12, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
            options.AddPolicy("password", c => RateLimitPartition.GetFixedWindowLimiter(c.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                _ => new FixedWindowRateLimiterOptions { PermitLimit = 6, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
        });
    }
    public static Task IssueCookie(HttpContext context, IssuedSession session) => context.SignInAsync(Scheme,
        new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, session.Secret)], Scheme)),
        new AuthenticationProperties { IsPersistent = false, AllowRefresh = false, ExpiresUtc = session.Data.Session.AbsoluteExpiresAt });
}

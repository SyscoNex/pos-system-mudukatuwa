using System.Security.Cryptography.X509Certificates;
using Conex360.Api.Identity;
using Conex360.Application.Identity;
using Conex360.Infrastructure.Identity;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Conex360.IntegrationTests;

internal static class IdentityTestHost
{
    // WebApplicationFactory's config callbacks run after this minimal host's registration.
    // Override concrete settings and cookie options explicitly, preserving the real auth/SQL pipeline.
    internal static void Configure(IServiceCollection services, bool database)
    {
        services.Replace(ServiceDescriptor.Singleton(new AuthPolicy { Enabled = database, AllowInsecureDevelopmentCookies = true, AllowedOrigins = ["http://localhost"] }));
        services.PostConfigure<CookieAuthenticationOptions>(IdentitySetup.Scheme, o => { o.Cookie.Name = "Conex360.Dev.Session"; o.Cookie.SecurePolicy = Microsoft.AspNetCore.Http.CookieSecurePolicy.None; });
        services.PostConfigure<AntiforgeryOptions>(o => { o.Cookie.Name = "Conex360.Dev.Csrf"; o.Cookie.SecurePolicy = Microsoft.AspNetCore.Http.CookieSecurePolicy.None; });
        if (!database) return;
        services.Replace(ServiceDescriptor.Singleton(new DatabaseSettings { Enabled = true, AllowUnverifiedDevelopmentTls = true, ConnectionFile = Environment.GetEnvironmentVariable("Database__ConnectionFile")! }));
        services.Replace(ServiceDescriptor.Singleton(new StorageSettings { LogoDirectory = "/evidence/test-logos" }));
        var certificate = X509CertificateLoader.LoadPkcs12FromFile("/run/secrets/dp_certificate", File.ReadAllText("/run/secrets/dp_password").Trim(), X509KeyStorageFlags.EphemeralKeySet);
        Directory.CreateDirectory("/evidence/test-keys");
        services.AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo("/evidence/test-keys")).ProtectKeysWithCertificate(certificate);
    }
}

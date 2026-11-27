using System.ComponentModel.DataAnnotations;
using System.Globalization;
using Conex360.Application.Identity;
using Conex360.Domain.Identity;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;

namespace Conex360.Api.Identity;

public sealed class CsrfFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext c, EndpointFilterDelegate next)
    {
        if (!HttpMethods.IsGet(c.HttpContext.Request.Method))
        {
            var policy = c.HttpContext.RequestServices.GetRequiredService<AuthPolicy>();
            var origin = c.HttpContext.Request.Headers.Origin.ToString();
            if (origin.Length > 0 && !policy.AllowedOrigins.Contains(origin, StringComparer.Ordinal))
                throw new AppFailure(400, "CSRF_REJECTED", "Refresh the page and try again.");
            try { await c.HttpContext.RequestServices.GetRequiredService<IAntiforgery>().ValidateRequestAsync(c.HttpContext); }
            catch (AntiforgeryValidationException) { throw new AppFailure(400, "CSRF_REJECTED", "Refresh the page and try again."); }
        }
        return await next(c);
    }
}
public sealed class BusinessContextFilter : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext c, EndpointFilterDelegate next)
    {
        var s = IdentitySetup.Session(c.HttpContext);
        var version = c.HttpContext.Request.Headers["X-Conex360-Context"].ToString();
        if (c.HttpContext.Request.Path == "/api/v1/business/logo" && HttpMethods.IsGet(c.HttpContext.Request.Method))
            version = c.HttpContext.Request.Query["context"].ToString();
        if (!ulong.TryParse(version, NumberStyles.None, CultureInfo.InvariantCulture, out var expected) || s.Session.ContextVersion != expected)
            throw new AppFailure(409, "CONTEXT_CHANGED", "Your business context changed. Refresh before continuing.");
        return await next(c);
    }
}
public sealed record LoginInput([Required, MaxLength(254)] string Email, [Required, MaxLength(128)] string Password);
public sealed record PasswordInput([Required, MaxLength(128)] string CurrentPassword, [Required, MaxLength(128)] string NewPassword);
public sealed record ContextInput(ulong MembershipId, ulong ExpectedContextVersion);

public static class IdentityEndpoints
{
    private static object SessionView(SessionData s, AuthPolicy p) => new
    {
        user = new { s.User.PublicId, s.User.DisplayName, s.User.MustChangePassword },
        memberships = s.Memberships.Select(m => new { m.Id, m.BusinessName, m.Role }),
        selectedMembershipId = s.Selected?.Id,
        s.Session.ContextVersion,
        s.Session.AbsoluteExpiresAt,
        idleExpiresAt = s.Session.LastActivityAt + p.Idle
    };
    public static void MapIdentity(this WebApplication app)
    {
        var auth = app.MapGroup("/api/v1/auth").AddEndpointFilter<CsrfFilter>();
        if (!app.Services.GetRequiredService<AuthPolicy>().Enabled) auth.ExcludeFromDescription();
        auth.MapGet("/csrf", (HttpContext h, IAntiforgery csrf) => Results.Ok(new { token = csrf.GetAndStoreTokens(h).RequestToken })).AllowAnonymous();
        auth.MapPost("/login", async (LoginInput input, HttpContext h, IdentityService service, AuthPolicy policy, CancellationToken ct) =>
        {
            if (!policy.Enabled) throw new AppFailure(503, "AUTH_UNAVAILABLE", "Sign-in has not been configured.");
            var issued = await service.LoginAsync(input.Email, input.Password, h.TraceIdentifier, ct);
            await IdentitySetup.IssueCookie(h, issued);
            return Results.Ok(SessionView(issued.Data, policy));
        }).AllowAnonymous().RequireRateLimiting("login");
        auth.MapGet("/session", (HttpContext h, AuthPolicy p) => Results.Ok(SessionView(IdentitySetup.Session(h), p)));
        auth.MapPost("/logout", async (HttpContext h, IdentityService service, CancellationToken ct) =>
        {
            await service.LogoutAsync(IdentitySetup.Session(h), h.TraceIdentifier, ct);
            await h.SignOutAsync(IdentitySetup.Scheme);
            return Results.NoContent();
        });
        auth.MapPost("/password", async (PasswordInput input, HttpContext h, IdentityService service, AuthPolicy p, CancellationToken ct) =>
        {
            var issued = await service.ChangePasswordAsync(IdentitySetup.Session(h), input.CurrentPassword, input.NewPassword, h.TraceIdentifier, ct);
            await IdentitySetup.IssueCookie(h, issued);
            return Results.Ok(SessionView(issued.Data, p));
        }).RequireRateLimiting("password");
        auth.MapPost("/context", async (ContextInput input, HttpContext h, IdentityService service, AuthPolicy p, CancellationToken ct) =>
        {
            var current = IdentitySetup.Session(h);
            if (current.Session.ContextVersion != input.ExpectedContextVersion) throw new AppFailure(409, "CONTEXT_CHANGED", "Your business context changed. Refresh before continuing.");
            return Results.Ok(SessionView(await service.SelectAsync(current, input.MembershipId, h.TraceIdentifier, ct), p));
        });
        auth.MapPost("/activity", async (HttpContext h, IdentityService service, CancellationToken ct) =>
        {
            await service.TouchAsync(IdentitySetup.Session(h), ct);
            return Results.NoContent();
        });
        var business = app.MapGroup("/api/v1/business").RequireAuthorization("Business")
            .AddEndpointFilter<CsrfFilter>().AddEndpointFilter<BusinessContextFilter>();
        if (!app.Services.GetRequiredService<AuthPolicy>().Enabled) business.ExcludeFromDescription();
        business.MapGet("/", async (HttpContext h, IdentityService service, CancellationToken ct) => Results.Ok(await service.BusinessAsync(IdentitySetup.Session(h), ct)));
        business.MapGet("/options", (BusinessPolicy p) => Results.Ok(new { currencies = p.Currencies.Keys.Order() }));
        business.MapPut("/", async (BusinessEdit edit, HttpContext h, IdentityService service, CancellationToken ct) =>
            Results.Ok(await service.UpdateBusinessAsync(IdentitySetup.Session(h), edit, h.TraceIdentifier, ct))).RequireAuthorization("Administrator");
        business.MapPost("/logo", async (HttpContext h, IdentityService service, ILogoStore logos, CancellationToken ct) =>
        {
            if (!ulong.TryParse(h.Request.Headers["X-Conex360-Version"], NumberStyles.None, CultureInfo.InvariantCulture, out var version))
                throw new AppFailure(400, "VERSION_REQUIRED", "Refresh business settings before uploading.");
            // Raw body avoids trusting multipart filenames or content-type for storage/validation.
            var s = IdentitySetup.Session(h);
            var m = s.Selected!;
            var key = await logos.SaveAsync(m.TenantId, m.CompanyId, h.Request.Body, ct);
            try { return Results.Ok(await service.SetLogoAsync(s, key, version, h.TraceIdentifier, ct)); }
            catch { await logos.RemoveNewAsync(m.TenantId, m.CompanyId, key, CancellationToken.None); throw; }
        }).RequireAuthorization("Administrator");
        business.MapGet("/logo", async (HttpContext h, IdentityService service, ILogoStore logos, CancellationToken ct) =>
        {
            var s = IdentitySetup.Session(h);
            var b = await service.BusinessAsync(s, ct);
            var bytes = b.LogoKey is null ? null : await logos.ReadAsync(b.TenantId, b.Id, b.LogoKey, ct);
            return bytes is null ? Results.NotFound() : Results.File(bytes, "image/png");
        });
    }
}

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Conex360.Application.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Conex360.IntegrationTests;

public sealed class IdentityHttpTests
{
    private sealed class Factory : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder) => builder.UseEnvironment("Development").ConfigureAppConfiguration((_, c) =>
            c.AddInMemoryCollection(new Dictionary<string, string?> { ["Authentication:AllowInsecureDevelopmentCookies"] = "true", ["Authentication:AllowedOrigins:0"] = "http://localhost" })).ConfigureServices(s => IdentityTestHost.Configure(s, false));
    }
    [Fact]
    public async Task ProtectedEndpointsDefaultDenyAndNeverRedirectToHtml()
    {
        await using var factory = new Factory(); using var c = factory.CreateClient();
        foreach (var path in new[] { "/api/v1/auth/session", "/api/v1/business/", "/api/v1/business/logo" })
        {
            var response = await c.GetAsync(path);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            Assert.Null(response.Headers.Location);
            Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        }
    }
    [Fact]
    public async Task LoginRejectsMissingCsrfAndForeignOriginBeforeDependencyAccess()
    {
        await using var factory = new Factory(); using var c = factory.CreateClient();
        var input = new { email = "synthetic@example.invalid", password = "incorrect" };
        Assert.True(factory.Services.GetRequiredService<AuthPolicy>().AllowInsecureDevelopmentCookies);
        var missing = await c.PostAsJsonAsync("/api/v1/auth/login", input);
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        Assert.Contains("CSRF_REJECTED", await missing.Content.ReadAsStringAsync());
        var csrf = (await c.GetFromJsonAsync<JsonElement>("/api/v1/auth/csrf")).GetProperty("token").GetString();
        c.DefaultRequestHeaders.Add("X-CSRF-TOKEN", csrf);
        c.DefaultRequestHeaders.Add("Origin", "https://attacker.invalid");
        Assert.Equal(HttpStatusCode.BadRequest, (await c.PostAsJsonAsync("/api/v1/auth/login", input)).StatusCode);
        c.DefaultRequestHeaders.Remove("Origin");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await c.PostAsJsonAsync("/api/v1/auth/login", input)).StatusCode);
    }
    [Fact]
    public async Task LoginThrottleRejectsWithoutDatabaseOrPasswordDisclosure()
    {
        await using var factory = new Factory(); using var c = factory.CreateClient();
        HttpResponseMessage? response = null;
        for (var i = 0; i < 13; i++) response = await c.PostAsJsonAsync("/api/v1/auth/login", new { email = "a@example.invalid", password = "incorrect" });
        Assert.Equal(HttpStatusCode.TooManyRequests, response!.StatusCode);
    }
}

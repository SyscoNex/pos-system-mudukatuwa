using System.Net;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Conex360.IntegrationTests;

public sealed class HealthEndpointTests
{
    [Theory]
    [InlineData("/api/v1/health")]
    [InlineData("/health/live")]
    [InlineData("/health/ready")]
    public async Task HealthIsUncachedAndExplicitlyProcessOnly(string path)
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder => builder.UseEnvironment("Testing"));
        using var client = factory.CreateClient();
        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.CacheControl?.NoStore);
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("healthy", json.RootElement.GetProperty("status").GetString());
        Assert.Equal("conex360-api", json.RootElement.GetProperty("service").GetString());
        Assert.Equal("process", json.RootElement.GetProperty("scope").GetString());
        Assert.True(DateTimeOffset.TryParse(json.RootElement.GetProperty("timestamp").GetString(), out _));
    }

    [Fact]
    public async Task UnknownApiRouteUsesSafeProblemDetails()
    {
        using var factory = new WebApplicationFactory<Program>();
        using var response = await factory.CreateClient().GetAsync("/api/v1/not-a-module");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("NOT_FOUND", json.RootElement.GetProperty("code").GetString());
        Assert.False(string.IsNullOrWhiteSpace(json.RootElement.GetProperty("traceId").GetString()));
    }

    [Fact]
    public async Task UnhandledFailureDoesNotExposeExceptionDetails()
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.UseEnvironment("Production");
            builder.ConfigureServices(services => services.Replace(ServiceDescriptor.Singleton<TimeProvider>(new FailingClock())));
        });
        using var response = await factory.CreateClient().GetAsync("/api/v1/health");
        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("sensitive-internal-detail", body);
        using var json = JsonDocument.Parse(body);
        Assert.Equal("INTERNAL_ERROR", json.RootElement.GetProperty("code").GetString());
        Assert.True(response.Headers.CacheControl?.NoStore);
    }

    [Fact]
    public async Task OpenApiIsNotExposedInProduction()
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder => builder.UseEnvironment("Production"));
        using var response = await factory.CreateClient().GetAsync("/openapi/v1.json");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DevelopmentOpenApiDescribesOnlyFoundationOperations()
    {
        using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder => builder.UseEnvironment("Development"));
        using var response = await factory.CreateClient().GetAsync("/openapi/v1.json");
        response.EnsureSuccessStatusCode();
        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Single(json.RootElement.GetProperty("paths").EnumerateObject());
        Assert.True(json.RootElement.GetProperty("paths").TryGetProperty("/api/v1/health", out _));
    }

    private sealed class FailingClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => throw new InvalidOperationException("sensitive-internal-detail");
    }
}

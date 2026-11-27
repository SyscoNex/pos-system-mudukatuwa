using Conex360.Application.Identity;
namespace Conex360.Api.Health;

public static class HealthEndpoints
{
    public static void MapFoundationHealth(this WebApplication app)
    {
        app.MapGet("/api/v1/health", GetHealth)
            .WithName("GetApiHealth")
            .WithTags("Health")
            .WithSummary("Checks the foundation API process. No database is configured.")
            .Produces<HealthResponse>().AllowAnonymous();
        app.MapGet("/health/live", GetHealth).ExcludeFromDescription().AllowAnonymous();
        app.MapGet("/health/ready", async (IDatabaseReadiness database, TimeProvider clock, CancellationToken ct) =>
        {
            if (!database.Enabled) return GetHealth(clock);
            var ready = await database.CheckAsync(ct);
            return Results.Json(new HealthResponse(ready ? "healthy" : "unavailable", "conex360-api", "0.1.0", "database", clock.GetUtcNow()), statusCode: ready ? 200 : 503);
        }).ExcludeFromDescription().AllowAnonymous();
    }

    private static IResult GetHealth(TimeProvider clock) => Results.Ok(new HealthResponse(
        "healthy", "conex360-api", "0.1.0", "process", clock.GetUtcNow()));
}

public sealed record HealthResponse(
    string Status,
    string Service,
    string Version,
    string Scope,
    DateTimeOffset Timestamp);

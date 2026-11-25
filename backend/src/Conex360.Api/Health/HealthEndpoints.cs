namespace Conex360.Api.Health;

public static class HealthEndpoints
{
    public static void MapFoundationHealth(this WebApplication app)
    {
        app.MapGet("/api/v1/health", GetHealth)
            .WithName("GetApiHealth")
            .WithTags("Health")
            .WithSummary("Checks the foundation API process. No database is configured.")
            .Produces<HealthResponse>();
        app.MapGet("/health/live", GetHealth).ExcludeFromDescription();
        app.MapGet("/health/ready", GetHealth).ExcludeFromDescription();
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

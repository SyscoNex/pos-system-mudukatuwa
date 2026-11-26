using System.Diagnostics;
using Conex360.Api.Errors;
using Conex360.Api.Health;
using Conex360.Api.Serialization;
using Microsoft.AspNetCore.Diagnostics;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(options =>
{
    options.UseUtcTimestamp = true;
    options.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffZ";
});
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = context =>
    {
        context.ProblemDetails.Type = "about:blank";
        context.ProblemDetails.Extensions.TryAdd("code", context.ProblemDetails.Status switch
        {
            400 => "INVALID_REQUEST",
            404 => "NOT_FOUND",
            405 => "METHOD_NOT_ALLOWED",
            _ => "REQUEST_FAILED"
        });
        context.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? context.HttpContext.TraceIdentifier;
    };
});
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddValidation();
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.Converters.Add(new DecimalStringConverter());
    options.SerializerOptions.Converters.Add(new UInt64StringConverter());
});
builder.Services.AddOpenApi();

var app = builder.Build();

app.Use(async (context, next) =>
{
    context.Response.Headers.CacheControl = "no-store";
    context.Response.Headers.XContentTypeOptions = "nosniff";
    context.Response.Headers["Referrer-Policy"] = "same-origin";
    var started = Stopwatch.GetTimestamp();
    try
    {
        await next(context);
    }
    finally
    {
        app.Logger.LogInformation(
            "HTTP {Method} {Endpoint} responded {StatusCode} in {ElapsedMs}ms; trace {TraceId}",
            context.Request.Method,
            context.GetEndpoint()?.DisplayName ?? "unmatched",
            context.Response.StatusCode,
            Stopwatch.GetElapsedTime(started).TotalMilliseconds,
            Activity.Current?.Id ?? context.TraceIdentifier);
    }
});
app.UseExceptionHandler(new ExceptionHandlerOptions
{
    // The handler logs sanitized metadata, rather than raw exception messages.
    SuppressDiagnosticsCallback = _ => true
});
app.UseStatusCodePages();
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapFoundationHealth();
app.Run();

public partial class Program;

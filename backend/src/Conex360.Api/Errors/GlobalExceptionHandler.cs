using System.ComponentModel.DataAnnotations;
using Conex360.Application.Identity;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using MySqlConnector;

namespace Conex360.Api.Errors;

public sealed class GlobalExceptionHandler(
    IProblemDetailsService problems,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context, Exception exception, CancellationToken cancellationToken)
    {
        var isInvalid = exception is BadHttpRequestException or ValidationException;
        var failure = exception as AppFailure;
        var unavailable = exception is MySqlException or IOException;
        var status = failure?.Status ?? (unavailable ? 503 : isInvalid ? 400 : 500);
        if (isInvalid)
        {
            logger.LogWarning("Invalid request with {ExceptionType}; trace {TraceId}",
                exception.GetType().Name, context.TraceIdentifier);
        }
        else
        {
            logger.LogError("Unhandled {ExceptionType}; trace {TraceId}",
                exception.GetType().Name, context.TraceIdentifier);
        }
        context.Response.StatusCode = status;
        return await problems.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = context,
            ProblemDetails = new ProblemDetails
            {
                Status = status,
                Title = failure?.Message ?? (unavailable ? "Business services are temporarily unavailable." : isInvalid ? "The request is invalid." : "An unexpected error occurred."),
                Extensions = { ["code"] = failure?.Code ?? (unavailable ? "DATABASE_UNAVAILABLE" : isInvalid ? "INVALID_REQUEST" : "INTERNAL_ERROR") }
            }
        });
    }
}

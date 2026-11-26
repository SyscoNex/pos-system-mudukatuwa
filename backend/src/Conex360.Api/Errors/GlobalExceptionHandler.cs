using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Conex360.Api.Errors;

public sealed class GlobalExceptionHandler(
    IProblemDetailsService problems,
    ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context, Exception exception, CancellationToken cancellationToken)
    {
        var isInvalid = exception is BadHttpRequestException or ValidationException;
        var status = isInvalid ? StatusCodes.Status400BadRequest : StatusCodes.Status500InternalServerError;
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
                Title = isInvalid ? "The request is invalid." : "An unexpected error occurred.",
                Extensions = { ["code"] = isInvalid ? "INVALID_REQUEST" : "INTERNAL_ERROR" }
            }
        });
    }
}

using BuildingBlocks.Domain.Exceptions;
using FluentValidation;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace BuildingBlocks.Api.ExceptionHandling;

/// <summary>
/// .NET 8 IExceptionHandler that maps known exception types to ProblemDetails responses.
/// Register with services.AddExceptionHandler&lt;GlobalExceptionHandler&gt;() and app.UseExceptionHandler().
/// </summary>
public sealed class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger) => _logger = logger;

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        var (status, title, type) = exception switch
        {
            NotFoundException => (StatusCodes.Status404NotFound, "Resource not found", "https://httpstatuses.com/404"),
            ValidationException => (StatusCodes.Status400BadRequest, "Validation failed", "https://httpstatuses.com/400"),
            DomainException => (StatusCodes.Status409Conflict, "Domain rule violated", "https://httpstatuses.com/409"),
            UnauthorizedAccessException => (StatusCodes.Status401Unauthorized, "Unauthorized", "https://httpstatuses.com/401"),
            _ => (StatusCodes.Status500InternalServerError, "An unexpected error occurred", "https://httpstatuses.com/500"),
        };

        if (status >= 500)
        {
            _logger.LogError(exception, "Unhandled exception for {Path}", httpContext.Request.Path);
        }
        else
        {
            _logger.LogWarning(
                exception,
                "Handled exception {ExceptionType} for {Path}",
                exception.GetType().Name,
                httpContext.Request.Path);
        }

        var problem = new ProblemDetails
        {
            Status = status,
            Title = title,
            Type = type,
            Detail = exception.Message,
            Instance = httpContext.Request.Path,
        };

        problem.Extensions["traceId"] = httpContext.TraceIdentifier;

        if (exception is ValidationException validationEx)
        {
            problem.Extensions["errors"] = validationEx.Errors
                .GroupBy(e => e.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorMessage).ToArray());
        }

        httpContext.Response.StatusCode = status;
        httpContext.Response.ContentType = "application/problem+json";
        await httpContext.Response.WriteAsJsonAsync(problem, cancellationToken).ConfigureAwait(false);

        return true;
    }
}

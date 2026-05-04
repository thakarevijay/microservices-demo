using System.Diagnostics;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BuildingBlocks.Application.Behaviors;

/// <summary>
/// Logs the start, end, and duration of every MediatR request.
/// Failures are logged at Warning, exceptions propagate to the exception middleware.
/// </summary>
public sealed class LoggingBehavior<TRequest, TResponse> : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    private readonly ILogger<LoggingBehavior<TRequest, TResponse>> _logger;

    public LoggingBehavior(ILogger<LoggingBehavior<TRequest, TResponse>> logger) =>
        _logger = logger;

    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var requestName = typeof(TRequest).Name;
        var stopwatch = Stopwatch.StartNew();

        _logger.LogInformation("Handling {RequestName}", requestName);

        try
        {
            var response = await next().ConfigureAwait(false);
            stopwatch.Stop();
            _logger.LogInformation(
                "Handled {RequestName} in {ElapsedMs} ms",
                requestName,
                stopwatch.ElapsedMilliseconds);
            return response;
        }
        catch (Exception ex)
        {
            stopwatch.Stop();
            _logger.LogError(
                ex,
                "Unhandled exception in {RequestName} after {ElapsedMs} ms",
                requestName,
                stopwatch.ElapsedMilliseconds);
            throw;
        }
    }
}

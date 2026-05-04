using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Api.RateLimiting;

public static class RateLimitingExtensions
{
    public const string DefaultPolicy = "default";

    /// <summary>
    /// Registers a sliding-window rate limiter (60 requests / 60s per partition).
    /// Partition key = authenticated user id, falling back to remote IP.
    /// </summary>
    public static IServiceCollection AddBuildingBlocksRateLimiting(this IServiceCollection services)
    {
        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            options.AddPolicy(DefaultPolicy, httpContext =>
            {
                var partition = httpContext.User?.Identity?.IsAuthenticated == true
                    ? httpContext.User.Identity.Name ?? "anon"
                    : httpContext.Connection.RemoteIpAddress?.ToString() ?? "anon";

                return RateLimitPartition.GetSlidingWindowLimiter(partition, _ => new SlidingWindowRateLimiterOptions
                {
                    PermitLimit = 60,
                    Window = TimeSpan.FromSeconds(60),
                    SegmentsPerWindow = 6,
                    QueueLimit = 0,
                    QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                });
            });
        });

        return services;
    }
}

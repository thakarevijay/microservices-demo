using HealthChecks.UI.Client;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Routing;

namespace BuildingBlocks.Api.HealthChecks;

public static class HealthCheckExtensions
{
    /// <summary>
    /// Maps two health endpoints:
    /// <c>/health/live</c> — process up (no dependency checks).
    /// <c>/health/ready</c> — all checks tagged <c>ready</c> green.
    /// Use these as Kubernetes liveness and readiness probes respectively.
    /// </summary>
    public static IEndpointRouteBuilder MapBuildingBlocksHealthChecks(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapHealthChecks("/health/live", new HealthCheckOptions
        {
            Predicate = _ => false,
            ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse,
        });

        endpoints.MapHealthChecks("/health/ready", new HealthCheckOptions
        {
            Predicate = check => check.Tags.Contains("ready"),
            ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse,
        });

        return endpoints;
    }
}

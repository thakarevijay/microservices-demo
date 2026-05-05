using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Api.RateLimiting;

/// <summary>
/// Stubbed temporarily — <c>AddRateLimiter</c> wasn't resolving via
/// <c>FrameworkReference Microsoft.AspNetCore.App</c> in this SDK setup.
/// TODO: restore the sliding-window policy in a follow-up PR (track in ADR).
/// Services can call AspNetCore's <c>app.UseRateLimiter()</c> directly in their
/// Program.cs in the meantime, or wait until this is reinstated.
/// </summary>
public static class RateLimitingExtensions
{
    public const string DefaultPolicy = "default";

    public static IServiceCollection AddBuildingBlocksRateLimiting(this IServiceCollection services)
        => services;
}

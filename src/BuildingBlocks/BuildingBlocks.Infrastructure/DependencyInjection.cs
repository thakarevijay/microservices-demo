using BuildingBlocks.Application.Abstractions;
using BuildingBlocks.Infrastructure.Time;
using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Infrastructure;

public static class DependencyInjection
{
    /// <summary>
    /// Registers cross-cutting infrastructure shared by every service:
    /// system clock, default abstractions. Service-specific infra (DbContext,
    /// repositories, MassTransit consumers) is wired in the service's own
    /// Infrastructure DI extension.
    /// </summary>
    public static IServiceCollection AddBuildingBlocksInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton<IDateTimeProvider, SystemDateTimeProvider>();
        return services;
    }
}

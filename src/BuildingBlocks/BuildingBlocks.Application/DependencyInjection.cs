using System.Reflection;
using BuildingBlocks.Application.Behaviors;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Application;

public static class DependencyInjection
{
    /// <summary>
    /// Registers MediatR, FluentValidation, and the standard pipeline behaviors
    /// (Logging → Validation → UnitOfWork) for the given application assembly.
    /// </summary>
    /// <remarks>
    /// Call from each service's Application layer DI extension, passing the
    /// service's Application assembly.
    /// </remarks>
    public static IServiceCollection AddBuildingBlocksApplication(
        this IServiceCollection services,
        Assembly applicationAssembly)
    {
        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(applicationAssembly);
            cfg.AddOpenBehavior(typeof(LoggingBehavior<,>));
            cfg.AddOpenBehavior(typeof(ValidationBehavior<,>));
            cfg.AddOpenBehavior(typeof(UnitOfWorkBehavior<,>));
        });

        services.AddValidatorsFromAssembly(applicationAssembly, includeInternalTypes: true);

        return services;
    }
}

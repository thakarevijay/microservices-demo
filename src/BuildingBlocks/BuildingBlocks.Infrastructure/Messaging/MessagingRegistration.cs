using System.Reflection;
using BuildingBlocks.Infrastructure.Outbox;
using MassTransit;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BuildingBlocks.Infrastructure.Messaging;

public static class MessagingRegistration
{
    /// <summary>
    /// Registers MassTransit + RabbitMQ with sensible defaults: kebab-case endpoint names,
    /// retry/redelivery policies, and consumer assembly scanning.
    /// </summary>
    public static IServiceCollection AddBuildingBlocksMessaging(
        this IServiceCollection services,
        IConfiguration configuration,
        params Assembly[] consumerAssemblies)
    {
        services.Configure<RabbitMqOptions>(configuration.GetSection(RabbitMqOptions.SectionName));

        services.AddMassTransit(bus =>
        {
            if (consumerAssemblies.Length > 0)
            {
                bus.AddConsumers(consumerAssemblies);
            }

            bus.SetKebabCaseEndpointNameFormatter();

            bus.UsingRabbitMq((context, cfg) =>
            {
                var options = configuration
                    .GetSection(RabbitMqOptions.SectionName)
                    .Get<RabbitMqOptions>() ?? new RabbitMqOptions();

                cfg.Host(options.Host, options.Port, options.VirtualHost, h =>
                {
                    h.Username(options.Username);
                    h.Password(options.Password);
                });

                cfg.UseMessageRetry(r => r.Intervals(
                    TimeSpan.FromSeconds(1),
                    TimeSpan.FromSeconds(5),
                    TimeSpan.FromSeconds(15)));

                cfg.UseDelayedRedelivery(r => r.Intervals(
                    TimeSpan.FromMinutes(1),
                    TimeSpan.FromMinutes(5),
                    TimeSpan.FromMinutes(15)));

                cfg.ConfigureEndpoints(context);
            });
        });

        services.AddScoped<IOutboxPublisher, MassTransitOutboxPublisher>();

        return services;
    }
}

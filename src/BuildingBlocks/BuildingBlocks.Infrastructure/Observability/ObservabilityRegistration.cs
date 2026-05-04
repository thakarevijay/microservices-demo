using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace BuildingBlocks.Infrastructure.Observability;

public static class ObservabilityRegistration
{
    /// <summary>
    /// Registers OpenTelemetry tracing + metrics with OTLP export.
    /// Reads endpoint from <c>OTEL_EXPORTER_OTLP_ENDPOINT</c> (env or config).
    /// </summary>
    /// <param name="serviceName">Logical service name, e.g. "orders-api".</param>
    public static IServiceCollection AddBuildingBlocksObservability(
        this IServiceCollection services,
        IConfiguration configuration,
        string serviceName)
    {
        var otlpEndpoint = configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]
            ?? Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT");

        var resource = ResourceBuilder.CreateDefault()
            .AddService(serviceName)
            .AddTelemetrySdk()
            .AddEnvironmentVariableDetector();

        services.AddOpenTelemetry()
            .ConfigureResource(r => r.AddService(serviceName))
            .WithTracing(t =>
            {
                t.AddAspNetCoreInstrumentation(o =>
                {
                    o.Filter = ctx => !ctx.Request.Path.StartsWithSegments("/health")
                                   && !ctx.Request.Path.StartsWithSegments("/metrics");
                });
                t.AddHttpClientInstrumentation();
                t.AddEntityFrameworkCoreInstrumentation();
                t.AddSource("MassTransit");

                if (!string.IsNullOrWhiteSpace(otlpEndpoint))
                {
                    t.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
                }
            })
            .WithMetrics(m =>
            {
                m.AddAspNetCoreInstrumentation();
                m.AddHttpClientInstrumentation();
                m.AddRuntimeInstrumentation();
                m.AddMeter("MassTransit");

                if (!string.IsNullOrWhiteSpace(otlpEndpoint))
                {
                    m.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
                }
            });

        return services;
    }
}

using Microsoft.AspNetCore.Builder;
using Serilog;
using Serilog.Formatting.Compact;

namespace BuildingBlocks.Api.Logging;

public static class SerilogRegistration
{
    /// <summary>
    /// Configures Serilog as the host logger.
    /// JSON to stdout (for Filebeat/Alloy), enriched with service + pod metadata,
    /// optionally exporting via OTLP if <c>OTEL_EXPORTER_OTLP_ENDPOINT</c> is set.
    /// </summary>
    public static WebApplicationBuilder UseBuildingBlocksSerilog(
        this WebApplicationBuilder builder,
        string serviceName)
    {
        var podName = Environment.GetEnvironmentVariable("POD_NAME") ?? "local";
        var otlpEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT");

        var loggerConfig = new LoggerConfiguration()
            .ReadFrom.Configuration(builder.Configuration)
            .Enrich.FromLogContext()
            .Enrich.WithMachineName()
            .Enrich.WithProcessId()
            .Enrich.WithProperty("Service", serviceName)
            .Enrich.WithProperty("Pod", podName)
            .WriteTo.Console(new CompactJsonFormatter());

        if (!string.IsNullOrWhiteSpace(otlpEndpoint))
        {
            loggerConfig = loggerConfig.WriteTo.OpenTelemetry(o =>
            {
                o.Endpoint = otlpEndpoint;
                o.ResourceAttributes = new Dictionary<string, object>
                {
                    ["service.name"] = serviceName,
                    ["pod.name"] = podName,
                };
            });
        }

        Log.Logger = loggerConfig.CreateLogger();
        builder.Host.UseSerilog();

        return builder;
    }
}

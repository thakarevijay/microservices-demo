using Microsoft.AspNetCore.HttpOverrides;
using Prometheus;
using Serilog;
using Serilog.Formatting.Compact;

var podName = Environment.GetEnvironmentVariable("POD_NAME") ?? "local";
var podIp = Environment.GetEnvironmentVariable("POD_IP") ?? "unknown";

// Configure Serilog BEFORE creating builder
Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithProcessId()
    .Enrich.WithProperty("Application", "ProductsApi")
    .Enrich.WithProperty("Pod", podName)
    .WriteTo.Console(new CompactJsonFormatter())   // JSON to stdout — Filebeat reads this
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();  // replace default logger
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

// ── Custom business metrics counters ──────────────────────────────────────
var requestCounter = Metrics.CreateCounter(
    "api_requests_total",
    "Total API requests",
    new CounterConfiguration
    {
        LabelNames = ["service", "endpoint", "pod"]
    });

var requestDuration = Metrics.CreateHistogram(
    "api_request_duration_seconds",
    "Request duration in seconds",
    new HistogramConfiguration
    {
        LabelNames = ["service", "endpoint"],
        Buckets = Histogram.LinearBuckets(start: 0.01, width: 0.05, count: 10)
    });

// For Products API only — business metrics  
var productsViewed = Metrics.CreateCounter(
    "products_viewed_total",
    "Total product views",
    new CounterConfiguration { LabelNames = ["product_id"] });

var app = builder.Build();
app.UseForwardedHeaders();
app.UseSerilogRequestLogging();  // logs every HTTP request automatically

// ── PROMETHEUS: expose /metrics endpoint ──────────────────────────────────
app.UseMetricServer();      // serves /metrics — Prometheus scrapes this
app.UseHttpMetrics();       // auto-tracks HTTP request count + duration

app.UseSwagger();
app.UseSwaggerUI();


var products = new[]
{
    new { Id = 1, Name = "Laptop",     Price = 1299.99m, Stock = 42 },
    new { Id = 2, Name = "Mouse",      Price = 29.99m,   Stock = 150 },
    new { Id = 3, Name = "Keyboard",   Price = 79.99m,   Stock = 88 },
    new { Id = 4, Name = "Monitor",    Price = 499.99m,  Stock = 23 },
    new { Id = 5, Name = "Headphones", Price = 149.99m,  Stock = 61 },
};

// HEALTH/VERSION ENDPOINTS GO HERE
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
app.MapGet("/version", () => Results.Ok(new
{
    service = "orders-api",
    commit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "local",
    builtAt = Environment.GetEnvironmentVariable("BUILD_TIME") ?? "unknown"
}));

app.MapGet("/products", (ILogger<Program> logger) =>
{
    using var timer = requestDuration.WithLabels("products-api", "/products").NewTimer();
    requestCounter.WithLabels("products-api", "/products", podName).Inc();
    logger.LogInformation("Listing {Count} products", products.Length);
    return new { pod = podName, ip = podIp, service = "products-api", count = products.Length, data = products };
});

app.MapGet("/products/{id:int}", (int id, ILogger<Program> logger) =>
{
    using var timer = requestDuration.WithLabels("products-api", "/products/{id}").NewTimer();
    requestCounter.WithLabels("products-api", "/products/{id}", podName).Inc();
    productsViewed.WithLabels(id.ToString()).Inc();   // business metric
    var p = products.FirstOrDefault(x => x.Id == id);
    if (p is null)
    {
        logger.LogWarning("Product {Id} not found", id);
        return Results.NotFound(new { error = $"Product {id} not found", pod = podName });
    }
    logger.LogInformation("Returning product {Id} = {Name}", id, p.Name);
    return Results.Ok(new { pod = podName, service = "products-api", data = p });
});

app.MapGet("/products/info", () => new { pod = podName, ip = podIp, service = "products-api" });
app.MapHealthChecks("/health");
app.MapGet("/ready", () => Results.Ok(new { status = "ready", pod = podName }));
app.MapPost("/crash", () => { Task.Delay(200).ContinueWith(_ => Environment.Exit(1)); return Results.Ok(new { pod = podName }); });


try
{
    Log.Information("Starting Products API on pod {Pod}", podName);
    await app.RunAsync("http://0.0.0.0:8080");

}
catch (Exception ex)
{
    Log.Fatal(ex, "Products API crashed");
}
finally
{
    await Log.CloseAndFlushAsync();
}
public partial class Program;

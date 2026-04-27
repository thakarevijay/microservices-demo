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
    .Enrich.WithProperty("Application", "OrdersApi")
    .Enrich.WithProperty("Pod", podName)
    .WriteTo.Console(new CompactJsonFormatter())   // JSON to stdout — Filebeat reads this
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();
builder.Services.AddHealthChecks();

// ── ADD THESE TWO LINES ──
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
        LabelNames = new[] { "service", "endpoint", "pod" }
    });

var requestDuration = Metrics.CreateHistogram(
    "api_request_duration_seconds",
    "Request duration in seconds",
    new HistogramConfiguration
    {
        LabelNames = new[] { "service", "endpoint" },
        Buckets = Histogram.LinearBuckets(start: 0.01, width: 0.05, count: 10)
    });

// For Orders API only — business metrics
var ordersCreated = Metrics.CreateCounter(
    "orders_viewed_total",
    "Total orders viewed",
    new CounterConfiguration { LabelNames = new[] { "status" } });

// HttpClient for calling Products API — uses K8s DNS service name
builder.Services.AddHttpClient("products", client =>
{
    // "products-service" = the K8s Service name defined in products-service.yaml
    // K8s DNS resolves this automatically inside the cluster
    client.BaseAddress = new Uri("http://products-service");
    client.Timeout = TimeSpan.FromSeconds(5);
});

var app = builder.Build();
app.UseForwardedHeaders();
app.UseSerilogRequestLogging();

// ── PROMETHEUS: expose /metrics endpoint ──────────────────────────────────
app.UseMetricServer();      // serves /metrics — Prometheus scrapes this
app.UseHttpMetrics();       // auto-tracks HTTP request count + duration
// ── ADD THESE TWO LINES (enable Swagger for all environments, not just Dev) ──
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "Products API v1");
    c.RoutePrefix = "swagger";
});


// Static orders data
var orders = new[]
{
    new { Id = 101, CustomerId = "C001", ProductId = 1, Quantity = 2, Status = "Delivered" },
    new { Id = 102, CustomerId = "C002", ProductId = 3, Quantity = 1, Status = "Pending"   },
    new { Id = 103, CustomerId = "C001", ProductId = 5, Quantity = 3, Status = "Shipped"   },
    new { Id = 104, CustomerId = "C003", ProductId = 2, Quantity = 5, Status = "Pending"   },
};

// HEALTH/VERSION ENDPOINTS GO HERE
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));
app.MapGet("/version", () => Results.Ok(new
{
    service = "orders-api",
    commit = Environment.GetEnvironmentVariable("GIT_COMMIT") ?? "local",
    builtAt = Environment.GetEnvironmentVariable("BUILD_TIME") ?? "unknown"
}));

// GET /orders — list all orders
app.MapGet("/orders", (ILogger<Program> logger) =>
{
    using var timer = requestDuration.WithLabels("orders-api", "/orders").NewTimer();
    requestCounter.WithLabels("orders-api", "/orders", podName).Inc();
    logger.LogInformation("Listing {Count} orders", orders.Length);
    return new
    {
        pod = podName,
        ip = podIp,
        service = "orders-api",
        count = orders.Length,
        data = orders
    };
});

// GET /orders/{id} — single order (no cross-service call)
app.MapGet("/orders/{id:int}", (int id, ILogger<Program> logger) =>
{
    using var timer = requestDuration.WithLabels("orders-api", "/orders/{id}").NewTimer();
    requestCounter.WithLabels("orders-api", "/orders/{id}", podName).Inc();
    ordersCreated.WithLabels(id.ToString()).Inc();   // business metric
    var order = orders.FirstOrDefault(o => o.Id == id);
    if (order is null)
    {
        logger.LogWarning("Order {Id} not found", id);
        return Results.NotFound(new { error = $"Order {id} not found", pod = podName });
    }
    logger.LogInformation("Returning order {Id} = {Name}", id, order.Id);
    return Results.Ok(new { pod = podName, service = "orders-api", data = order });
});

// GET /orders/{id}/detail — enriches order WITH product data from Products API
// This demonstrates K8s service-to-service discovery
app.MapGet("/orders/{id:int}/detail", async (int id, IHttpClientFactory factory, ILogger<Program> logger) =>
{
    logger.LogInformation("Fetching detail for order {OrderId} from pod {Pod}", id, podName);
    var order = orders.FirstOrDefault(o => o.Id == id);
    if (order is null)
    {
        logger.LogWarning("Order {Id} not found", id);
        return Results.NotFound(new { error = $"Order {id} not found", pod = podName });
    }

    try
    {
        var client = factory.CreateClient("products");

        // Calls Products API via K8s internal DNS — never leaves the cluster
        var product = await client.GetFromJsonAsync<object>($"/products/{order.ProductId}");
        logger.LogInformation("Returning order {Id} = {Name}", id, order.Id);
        return Results.Ok(new
        {
            pod = podName,
            service = "orders-api",
            calledService = "products-api",           // proves cross-service call worked
            order = order,
            productDetails = product                   // data fetched from Products API
        });
    }
    catch (Exception ex)
    {
        // Returns partial data if Products API is down — graceful degradation
        return Results.Ok(new
        {
            pod = podName,
            service = "orders-api",
            order = order,
            productDetails = (object?)null,
            warning = $"Products API unavailable: {ex.Message}"
        });
    }
});

// GET /orders/info
app.MapGet("/orders/info", (ILogger<Program> logger) =>
{
    logger.LogInformation("Retrieving order information from pod {Pod}", podName);
    return new
    {
        pod = podName,
        ip = podIp,
        service = "orders-api",
        productsApiUrl = "http://products-service",   // K8s DNS name
        time = DateTime.UtcNow
    };
});

app.MapHealthChecks("/health");
app.MapGet("/ready", () => Results.Ok(new { status = "ready", pod = podName, service = "orders-api" }));
app.MapPost("/crash", () => { Task.Delay(200).ContinueWith(_ => Environment.Exit(1)); return Results.Ok(new { pod = podName }); });


app.Run("http://0.0.0.0:8080");
public partial class Program;
#!/bin/bash
# =============================================================================
# MASTER DEPLOYMENT SCRIPT
# .NET Microservices + Docker + K8s + Terraform + Ansible + ELK Stack
# Run this on any fresh Ubuntu/WSL server to deploy everything from scratch
# =============================================================================

set -e  # Exit on any error
STUDY_DIR="$HOME/Study/microservices-demo"
LOG_FILE="/tmp/deploy-$(date +%Y%m%d-%H%M%S).log"

# Colours
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "${BLUE}➜ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

echo "============================================="
echo " FULL MICROSERVICES DEPLOYMENT"
echo " Log: $LOG_FILE"
echo "============================================="
exec > >(tee -a "$LOG_FILE") 2>&1

# =============================================================================
# PHASE 1 — INSTALL PREREQUISITES
# =============================================================================
info "PHASE 1: Installing prerequisites..."

# Docker
if ! command -v docker &>/dev/null; then
  info "Installing Docker..."
  sudo apt-get update -q
  sudo apt-get install -y -q ca-certificates curl gnupg
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -q && sudo apt-get install -y -q docker-ce docker-ce-cli containerd.io
  sudo usermod -aG docker $USER
  ok "Docker installed"
else
  ok "Docker already installed: $(docker --version)"
fi

# kubectl
if ! command -v kubectl &>/dev/null; then
  info "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install kubectl /usr/local/bin/kubectl && rm kubectl
  ok "kubectl installed"
else
  ok "kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo 'ok')"
fi

# minikube
if ! command -v minikube &>/dev/null; then
  info "Installing minikube..."
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
  ok "minikube installed"
else
  ok "minikube already installed: $(minikube version --short)"
fi

# .NET 8 SDK
if ! command -v dotnet &>/dev/null; then
  info "Installing .NET 8 SDK..."
  wget -q https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
  chmod +x dotnet-install.sh
  ./dotnet-install.sh --channel 8.0 --no-path
  rm dotnet-install.sh
  export PATH="$PATH:$HOME/.dotnet"
  echo 'export PATH="$PATH:$HOME/.dotnet"' >> ~/.bashrc
  ok ".NET 8 SDK installed"
else
  ok ".NET already installed: $(dotnet --version)"
fi

# Terraform
if ! command -v terraform &>/dev/null; then
  info "Installing Terraform..."
  sudo apt-get update -q && sudo apt-get install -y -q gnupg software-properties-common
  wget -q -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update -q && sudo apt-get install -y -q terraform
  ok "Terraform installed"
else
  ok "Terraform already installed: $(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)["terraform_version"])' 2>/dev/null || echo 'ok')"
fi

# Ansible
if ! command -v ansible &>/dev/null; then
  info "Installing Ansible..."
  sudo apt-get install -y -q ansible
  ok "Ansible installed"
else
  ok "Ansible already installed: $(ansible --version | head -1)"
fi

# =============================================================================
# PHASE 2 — START MINIKUBE
# =============================================================================
info "PHASE 2: Starting minikube..."

MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")
if [ "$MINIKUBE_STATUS" != "Running" ]; then
  # Check available memory
  TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
  if [ "$TOTAL_MEM" -gt 7000 ]; then
    MINIKUBE_MEM="6g"
  else
    MINIKUBE_MEM="4g"
  fi
  info "Starting minikube with ${MINIKUBE_MEM} RAM..."
  minikube start --driver=docker --cpus=4 --memory=$MINIKUBE_MEM
else
  ok "minikube already running"
fi

minikube addons enable ingress 2>/dev/null || true
minikube addons enable metrics-server 2>/dev/null || true
minikube addons enable dashboard 2>/dev/null || true
minikube update-context
kubectl config use-context minikube

# Fix inotify limits (prevents .NET CrashLoopBackOff)
sudo sysctl -w fs.inotify.max_user_instances=512 > /dev/null
sudo sysctl -w fs.inotify.max_user_watches=524288 > /dev/null
grep -q "max_user_instances" /etc/sysctl.conf || echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf > /dev/null
grep -q "max_user_watches" /etc/sysctl.conf || echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf > /dev/null

ok "minikube running: $(minikube ip)"

# =============================================================================
# PHASE 3 — CREATE PROJECT STRUCTURE
# =============================================================================
info "PHASE 3: Creating project structure..."

mkdir -p $STUDY_DIR/{OrdersApi,ProductsApi,k8s,k8s-elk,terraform,ansible/roles/{prerequisites,docker_build,k8s_deploy}/tasks}

# ---------- ProductsApi ----------
cat > $STUDY_DIR/ProductsApi/ProductsApi.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Diagnostics.HealthChecks" Version="2.2.0" />
    <PackageReference Include="Serilog.AspNetCore" Version="8.0.0" />
    <PackageReference Include="Serilog.Sinks.Console" Version="5.0.1" />
    <PackageReference Include="Serilog.Formatting.Compact" Version="2.0.0" />
    <PackageReference Include="Serilog.Enrichers.Environment" Version="2.3.0" />
    <PackageReference Include="Serilog.Enrichers.Process" Version="2.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
  </ItemGroup>
</Project>
EOF

cat > $STUDY_DIR/ProductsApi/Program.cs << 'EOF'
using Microsoft.AspNetCore.HttpOverrides;
using Serilog;
using Serilog.Formatting.Compact;

var podName = Environment.GetEnvironmentVariable("POD_NAME") ?? "local";
var podIp   = Environment.GetEnvironmentVariable("POD_IP")   ?? "unknown";

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithProcessId()
    .Enrich.WithProperty("Application", "ProductsApi")
    .Enrich.WithProperty("Pod", podName)
    .WriteTo.Console(new CompactJsonFormatter())
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.Configure<ForwardedHeadersOptions>(options => {
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var app = builder.Build();
app.UseForwardedHeaders();
app.UseSerilogRequestLogging();
app.UseSwagger();
app.UseSwaggerUI();

var products = new[] {
    new { Id = 1, Name = "Laptop",     Price = 1299.99m, Stock = 42 },
    new { Id = 2, Name = "Mouse",      Price = 29.99m,   Stock = 150 },
    new { Id = 3, Name = "Keyboard",   Price = 79.99m,   Stock = 88 },
    new { Id = 4, Name = "Monitor",    Price = 499.99m,  Stock = 23 },
    new { Id = 5, Name = "Headphones", Price = 149.99m,  Stock = 61 },
};

app.MapGet("/products", (ILogger<Program> logger) => {
    logger.LogInformation("Listing all {Count} products from pod {Pod}", products.Length, podName);
    return new { pod = podName, ip = podIp, service = "products-api", count = products.Length, data = products };
});

app.MapGet("/products/{id:int}", (int id, ILogger<Program> logger) => {
    var p = products.FirstOrDefault(x => x.Id == id);
    if (p is null) { logger.LogWarning("Product {Id} not found", id); return Results.NotFound(new { error = $"Product {id} not found", pod = podName }); }
    logger.LogInformation("Returning product {Id} = {Name}", id, p.Name);
    return Results.Ok(new { pod = podName, service = "products-api", data = p });
});

app.MapGet("/products/info", () => new { pod = podName, ip = podIp, service = "products-api", time = DateTime.UtcNow });
app.MapGet("/proxy-info", (HttpContext ctx) => Results.Ok(new {
    realClientIp    = ctx.Connection.RemoteIpAddress?.ToString(),
    xForwardedFor   = ctx.Request.Headers["X-Forwarded-For"].ToString(),
    xForwardedProto = ctx.Request.Headers["X-Forwarded-Proto"].ToString(),
    pod = podName
}));
app.MapHealthChecks("/health");
app.MapGet("/ready", () => Results.Ok(new { status = "ready", pod = podName, service = "products-api" }));
app.MapPost("/crash", () => { Task.Delay(200).ContinueWith(_ => Environment.Exit(1)); return Results.Ok(new { message = "Crashing...", pod = podName }); });

try { Log.Information("Starting ProductsApi on {Pod}", podName); app.Run("http://0.0.0.0:8080"); }
catch (Exception ex) { Log.Fatal(ex, "ProductsApi crashed"); }
finally { Log.CloseAndFlush(); }
EOF

cat > $STUDY_DIR/ProductsApi/Dockerfile << 'EOF'
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "ProductsApi.dll"]
EOF

# ---------- OrdersApi ----------
cat > $STUDY_DIR/OrdersApi/OrdersApi.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Diagnostics.HealthChecks" Version="2.2.0" />
    <PackageReference Include="Serilog.AspNetCore" Version="8.0.0" />
    <PackageReference Include="Serilog.Sinks.Console" Version="5.0.1" />
    <PackageReference Include="Serilog.Formatting.Compact" Version="2.0.0" />
    <PackageReference Include="Serilog.Enrichers.Environment" Version="2.3.0" />
    <PackageReference Include="Serilog.Enrichers.Process" Version="2.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
  </ItemGroup>
</Project>
EOF

cat > $STUDY_DIR/OrdersApi/Program.cs << 'EOF'
using Microsoft.AspNetCore.HttpOverrides;
using Serilog;
using Serilog.Formatting.Compact;

var podName = Environment.GetEnvironmentVariable("POD_NAME") ?? "local";
var podIp   = Environment.GetEnvironmentVariable("POD_IP")   ?? "unknown";

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithMachineName()
    .Enrich.WithProcessId()
    .Enrich.WithProperty("Application", "OrdersApi")
    .Enrich.WithProperty("Pod", podName)
    .WriteTo.Console(new CompactJsonFormatter())
    .CreateLogger();

var builder = WebApplication.CreateBuilder(args);
builder.Host.UseSerilog();
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.Configure<ForwardedHeadersOptions>(options => {
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});
builder.Services.AddHttpClient("products", client => {
    client.BaseAddress = new Uri(Environment.GetEnvironmentVariable("PRODUCTS_SERVICE_URL") ?? "http://products-service");
    client.Timeout = TimeSpan.FromSeconds(5);
});

var app = builder.Build();
app.UseForwardedHeaders();
app.UseSerilogRequestLogging();
app.UseSwagger();
app.UseSwaggerUI();

var orders = new[] {
    new { Id = 101, CustomerId = "C001", ProductId = 1, Quantity = 2, Status = "Delivered" },
    new { Id = 102, CustomerId = "C002", ProductId = 3, Quantity = 1, Status = "Pending"   },
    new { Id = 103, CustomerId = "C001", ProductId = 5, Quantity = 3, Status = "Shipped"   },
    new { Id = 104, CustomerId = "C003", ProductId = 2, Quantity = 5, Status = "Pending"   },
};

app.MapGet("/orders", (ILogger<Program> logger) => {
    logger.LogInformation("Listing {Count} orders from pod {Pod}", orders.Length, podName);
    return new { pod = podName, ip = podIp, service = "orders-api", count = orders.Length, data = orders };
});

app.MapGet("/orders/{id:int}", (int id, ILogger<Program> logger) => {
    var o = orders.FirstOrDefault(x => x.Id == id);
    if (o is null) { logger.LogWarning("Order {Id} not found", id); return Results.NotFound(new { error = $"Order {id} not found", pod = podName }); }
    logger.LogInformation("Returning order {Id}", id);
    return Results.Ok(new { pod = podName, service = "orders-api", data = o });
});

app.MapGet("/orders/{id:int}/detail", async (int id, IHttpClientFactory factory, ILogger<Program> logger) => {
    var o = orders.FirstOrDefault(x => x.Id == id);
    if (o is null) return Results.NotFound(new { error = $"Order {id} not found" });
    try {
        var client = factory.CreateClient("products");
        var product = await client.GetFromJsonAsync<object>($"/products/{o.ProductId}");
        logger.LogInformation("Enriched order {Id} with product {ProductId}", id, o.ProductId);
        return Results.Ok(new { pod = podName, service = "orders-api", calledService = "products-api", order = o, productDetails = product });
    } catch (Exception ex) {
        logger.LogWarning("Products API unavailable: {Error}", ex.Message);
        return Results.Ok(new { pod = podName, service = "orders-api", order = o, productDetails = (object?)null, warning = $"Products API unavailable: {ex.Message}" });
    }
});

app.MapGet("/orders/info", () => new { pod = podName, ip = podIp, service = "orders-api", time = DateTime.UtcNow });
app.MapHealthChecks("/health");
app.MapGet("/ready", () => Results.Ok(new { status = "ready", pod = podName, service = "orders-api" }));
app.MapPost("/crash", () => { Task.Delay(200).ContinueWith(_ => Environment.Exit(1)); return Results.Ok(new { message = "Crashing...", pod = podName }); });

try { Log.Information("Starting OrdersApi on {Pod}", podName); app.Run("http://0.0.0.0:8080"); }
catch (Exception ex) { Log.Fatal(ex, "OrdersApi crashed"); }
finally { Log.CloseAndFlush(); }
EOF

cat > $STUDY_DIR/OrdersApi/Dockerfile << 'EOF'
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "OrdersApi.dll"]
EOF

ok "Source code created"

# ---------- Terraform ----------
cat > $STUDY_DIR/terraform/variables.tf << 'EOF'
variable "namespace"         { default = "microservices" }
variable "orders_replicas"   { default = 2 }
variable "products_replicas" { default = 2 }
variable "environment"       { default = "local" }
EOF

cat > $STUDY_DIR/terraform/outputs.tf << 'EOF'
output "namespace"     { value = kubernetes_namespace.microservices.metadata[0].name }
output "products_url"  { value = "http://localhost:5001/products" }
output "orders_url"    { value = "http://localhost:5002/orders" }
EOF

cat > $STUDY_DIR/terraform/main.tf << 'EOF'
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23" }
  }
}
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "minikube"
}
resource "kubernetes_namespace" "microservices" {
  metadata { name = var.namespace; labels = { managed-by = "terraform", environment = var.environment } }
}
resource "kubernetes_config_map" "app_config" {
  metadata { name = "app-config"; namespace = kubernetes_namespace.microservices.metadata[0].name }
  data = { ENVIRONMENT = var.environment, PRODUCTS_SERVICE_URL = "http://products-service" }
}
resource "kubernetes_secret" "app_secrets" {
  metadata { name = "app-secrets"; namespace = kubernetes_namespace.microservices.metadata[0].name }
  data = { API_KEY = "demo-secret-key" }
  type = "Opaque"
}
resource "kubernetes_deployment" "products" {
  metadata { name = "products-deployment"; namespace = kubernetes_namespace.microservices.metadata[0].name; labels = { app = "products-api", managed-by = "terraform" } }
  spec {
    replicas = var.products_replicas
    selector { match_labels = { app = "products-api" } }
    template {
      metadata { labels = { app = "products-api" } }
      spec {
        container {
          name = "products-api"; image = "products-api:v1"; image_pull_policy = "Never"
          port { container_port = 8080 }
          env { name = "POD_NAME"; value_from { field_ref { field_path = "metadata.name" } } }
          env { name = "POD_IP";   value_from { field_ref { field_path = "status.podIP" } } }
          env { name = "ASPNETCORE_URLS"; value = "http://0.0.0.0:8080" }
          resources { requests = { memory = "64Mi", cpu = "50m" }; limits = { memory = "128Mi", cpu = "200m" } }
          liveness_probe  { http_get { path = "/health"; port = 8080 }; initial_delay_seconds = 5;  period_seconds = 10 }
          readiness_probe { http_get { path = "/ready";  port = 8080 }; initial_delay_seconds = 3;  period_seconds = 5  }
        }
      }
    }
  }
}
resource "kubernetes_service" "products" {
  metadata { name = "products-service"; namespace = kubernetes_namespace.microservices.metadata[0].name }
  spec { selector = { app = "products-api" }; port { port = 80; target_port = 8080 }; type = "ClusterIP" }
}
resource "kubernetes_deployment" "orders" {
  metadata { name = "orders-deployment"; namespace = kubernetes_namespace.microservices.metadata[0].name; labels = { app = "orders-api", managed-by = "terraform" } }
  spec {
    replicas = var.orders_replicas
    selector { match_labels = { app = "orders-api" } }
    template {
      metadata { labels = { app = "orders-api" } }
      spec {
        container {
          name = "orders-api"; image = "orders-api:v1"; image_pull_policy = "Never"
          port { container_port = 8080 }
          env { name = "POD_NAME"; value_from { field_ref { field_path = "metadata.name" } } }
          env { name = "POD_IP";   value_from { field_ref { field_path = "status.podIP" } } }
          env { name = "ASPNETCORE_URLS";       value = "http://0.0.0.0:8080" }
          env { name = "PRODUCTS_SERVICE_URL";  value = "http://products-service" }
          resources { requests = { memory = "64Mi", cpu = "50m" }; limits = { memory = "128Mi", cpu = "200m" } }
          liveness_probe  { http_get { path = "/health"; port = 8080 }; initial_delay_seconds = 5;  period_seconds = 10 }
          readiness_probe { http_get { path = "/ready";  port = 8080 }; initial_delay_seconds = 3;  period_seconds = 5  }
        }
      }
    }
  }
}
resource "kubernetes_service" "orders" {
  metadata { name = "orders-service"; namespace = kubernetes_namespace.microservices.metadata[0].name }
  spec { selector = { app = "orders-api" }; port { port = 80; target_port = 8080 }; type = "ClusterIP" }
}
resource "kubernetes_ingress_v1" "microservices" {
  metadata {
    name = "microservices-ingress"; namespace = kubernetes_namespace.microservices.metadata[0].name
    annotations = {
      "nginx.ingress.kubernetes.io/use-forwarded-headers"      = "true"
      "nginx.ingress.kubernetes.io/compute-full-forwarded-for" = "true"
      "nginx.ingress.kubernetes.io/enable-cors"                = "true"
      "nginx.ingress.kubernetes.io/cors-allow-origin"          = "*"
    }
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "api.local"
      http {
        path { path = "/products"; path_type = "Prefix"; backend { service { name = kubernetes_service.products.metadata[0].name; port { number = 80 } } } }
        path { path = "/orders";   path_type = "Prefix"; backend { service { name = kubernetes_service.orders.metadata[0].name;   port { number = 80 } } } }
      }
    }
  }
}
EOF

ok "Terraform files created"

# ---------- ELK K8s manifests ----------
cat > $STUDY_DIR/k8s-elk/00-namespace.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: logging
EOF

cat > $STUDY_DIR/k8s-elk/01-elasticsearch.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: logging
spec:
  serviceName: elasticsearch
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
        ports:
        - containerPort: 9200
        env:
        - { name: discovery.type,         value: single-node }
        - { name: xpack.security.enabled, value: "false" }
        - { name: ES_JAVA_OPTS,           value: "-Xms512m -Xmx512m" }
        - { name: bootstrap.memory_lock,  value: "false" }
        resources:
          requests: { memory: "1Gi",  cpu: "200m" }
          limits:   { memory: "1.5Gi", cpu: "1000m" }
        readinessProbe:
          httpGet: { path: /_cluster/health, port: 9200 }
          initialDelaySeconds: 30
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: logging
spec:
  selector: { app: elasticsearch }
  ports: [{ port: 9200, targetPort: 9200 }]
  type: ClusterIP
EOF

cat > $STUDY_DIR/k8s-elk/02-kibana.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:8.11.0
        ports:
        - containerPort: 5601
        env:
        - { name: ELASTICSEARCH_HOSTS, value: "http://elasticsearch:9200" }
        resources:
          requests: { memory: "512Mi", cpu: "100m" }
          limits:   { memory: "1Gi",   cpu: "500m" }
        readinessProbe:
          httpGet: { path: /api/status, port: 5601 }
          initialDelaySeconds: 60
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  selector: { app: kibana }
  ports: [{ port: 5601, targetPort: 5601 }]
  type: ClusterIP
EOF

cat > $STUDY_DIR/k8s-elk/03-logstash.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-config
  namespace: logging
data:
  logstash.conf: |
    input { beats { port => 5044 } }
    filter {
      if [kubernetes][namespace] == "microservices" {
        json { source => "message"; skip_on_invalid_json => true; target => "parsed" }
        if [parsed] {
          mutate {
            add_field => {
              "log_level"    => "%{[parsed][@l]}"
              "message_text" => "%{[parsed][@mt]}"
              "application"  => "%{[parsed][Application]}"
              "pod_name"     => "%{[parsed][Pod]}"
            }
          }
        }
      }
    }
    output {
      elasticsearch { hosts => ["http://elasticsearch:9200"]; index => "microservices-logs-%{+YYYY.MM.dd}" }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logstash
  template:
    metadata:
      labels:
        app: logstash
    spec:
      containers:
      - name: logstash
        image: docker.elastic.co/logstash/logstash:8.11.0
        ports:
        - containerPort: 5044
        env:
        - { name: LS_JAVA_OPTS, value: "-Xms256m -Xmx256m" }
        volumeMounts:
        - { name: config, mountPath: /usr/share/logstash/pipeline }
        resources:
          requests: { memory: "512Mi", cpu: "100m" }
          limits:   { memory: "1Gi",   cpu: "500m" }
      volumes:
      - name: config
        configMap: { name: logstash-config }
---
apiVersion: v1
kind: Service
metadata:
  name: logstash
  namespace: logging
spec:
  selector: { app: logstash }
  ports: [{ port: 5044, targetPort: 5044 }]
  type: ClusterIP
EOF

cat > $STUDY_DIR/k8s-elk/04-filebeat.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
rules:
- apiGroups: [""]
  resources: ["namespaces","pods","nodes"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: logging
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: logging
data:
  filebeat.yml: |
    filebeat.autodiscover:
      providers:
      - type: kubernetes
        node: ${NODE_NAME}
        hints.enabled: true
        templates:
        - condition:
            equals: { kubernetes.namespace: microservices }
          config:
          - type: container
            paths: ["/var/log/containers/*-${data.kubernetes.container.id}.log"]
    processors:
    - add_kubernetes_metadata:
        host: ${NODE_NAME}
        matchers:
        - logs_path: { logs_path: "/var/log/containers/" }
    output.logstash:
      hosts: ["logstash:5044"]
    logging.level: debug
    logging.to_stderr: true
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: logging
spec:
  selector:
    matchLabels:
      app: filebeat
  template:
    metadata:
      labels:
        app: filebeat
    spec:
      serviceAccountName: filebeat
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat:8.11.0
        args: ["-c", "/etc/filebeat.yml", "-e"]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef: { fieldPath: spec.nodeName }
        securityContext:
          runAsUser: 0
          privileged: true
        resources:
          requests: { memory: "100Mi", cpu: "100m" }
          limits:   { memory: "200Mi", cpu: "500m" }
        volumeMounts:
        - { name: config,                mountPath: /etc/filebeat.yml, subPath: filebeat.yml, readOnly: true }
        - { name: varlog,                mountPath: /var/log,                  readOnly: true }
        - { name: varlibdockercontainers, mountPath: /var/lib/docker/containers, readOnly: true }
        - { name: data,                  mountPath: /usr/share/filebeat/data }
      volumes:
      - { name: config,                configMap: { name: filebeat-config } }
      - { name: varlog,                hostPath: { path: /var/log } }
      - { name: varlibdockercontainers, hostPath: { path: /var/lib/docker/containers } }
      - { name: data,                  hostPath: { path: /var/lib/filebeat-data, type: DirectoryOrCreate } }
EOF

ok "ELK manifests created"

# ---------- Ansible ----------
cat > $STUDY_DIR/ansible/inventory.ini << 'EOF'
[local]
localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3
EOF

cat > $STUDY_DIR/ansible/playbook.yml << 'EOF'
---
- name: Deploy microservices to minikube
  hosts: local
  gather_facts: true
  roles:
    - prerequisites
    - docker_build
    - k8s_deploy
  post_tasks:
  - name: Done
    debug:
      msg:
        - "Deployment complete!"
        - "Products : http://localhost:5001/products"
        - "Swagger P: http://localhost:5001/swagger"
        - "Orders   : http://localhost:5002/orders"
        - "Swagger O: http://localhost:5002/swagger"
        - "Kibana   : http://localhost:5601"
EOF

cat > $STUDY_DIR/ansible/roles/prerequisites/tasks/main.yml << 'EOF'
---
- name: Check minikube status
  command: minikube status
  register: minikube_status
  ignore_errors: true

- name: Start minikube if not running
  command: minikube start --driver=docker --cpus=4 --memory=6g
  when: "'Running' not in minikube_status.stdout"

- name: Enable ingress addon
  command: minikube addons enable ingress
  ignore_errors: true

- name: Fix inotify limits
  become: true
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    sysctl_set: true
    state: present
    reload: true
  loop:
    - { name: fs.inotify.max_user_instances, value: "512" }
    - { name: fs.inotify.max_user_watches,   value: "524288" }

- name: Wait for ingress controller
  command: >
    kubectl wait --namespace ingress-nginx
    --for=condition=ready pod
    --selector=app.kubernetes.io/component=controller
    --timeout=120s
  ignore_errors: true
EOF

cat > $STUDY_DIR/ansible/roles/docker_build/tasks/main.yml << 'EOF'
---
- name: Build Products API image
  shell: |
    eval $(minikube docker-env)
    cd ~/Study/microservices-demo/ProductsApi
    docker build -t products-api:v1 .

- name: Build Orders API image
  shell: |
    eval $(minikube docker-env)
    cd ~/Study/microservices-demo/OrdersApi
    docker build -t orders-api:v1 .

- name: Confirm images
  shell: |
    eval $(minikube docker-env)
    docker images | grep -E "orders-api|products-api"
  register: images

- debug:
    msg: "{{ images.stdout_lines }}"
EOF

cat > $STUDY_DIR/ansible/roles/k8s_deploy/tasks/main.yml << 'EOF'
---
- name: Terraform init
  command: terraform init
  args:
    chdir: ~/Study/microservices-demo/terraform

- name: Terraform apply
  command: terraform apply -auto-approve
  args:
    chdir: ~/Study/microservices-demo/terraform

- name: Wait for products pods
  command: kubectl wait deployment/products-deployment --for=condition=available --timeout=120s --namespace=microservices

- name: Wait for orders pods
  command: kubectl wait deployment/orders-deployment --for=condition=available --timeout=120s --namespace=microservices

- name: Kill old port-forwards
  shell: pkill -f "kubectl port-forward" || true
  ignore_errors: true

- name: Port-forward products (background)
  shell: |
    nohup kubectl port-forward service/products-service 5001:80 -n microservices --address=0.0.0.0 > /tmp/products-pf.log 2>&1 &
    disown $!
  async: 10
  poll: 0
  ignore_errors: true

- name: Port-forward orders (background)
  shell: |
    nohup kubectl port-forward service/orders-service 5002:80 -n microservices --address=0.0.0.0 > /tmp/orders-pf.log 2>&1 &
    disown $!
  async: 10
  poll: 0
  ignore_errors: true

- name: Wait for port-forwards
  pause:
    seconds: 8

- name: Smoke test products
  uri:
    url: "http://localhost:5001/products"
    status_code: 200
  retries: 5
  delay: 5
  register: products_test
  until: products_test.status == 200

- name: Smoke test orders
  uri:
    url: "http://localhost:5002/orders"
    status_code: 200
  retries: 5
  delay: 5
  register: orders_test
  until: orders_test.status == 200

- name: Results
  debug:
    msg:
      - "Products : HTTP {{ products_test.status }}"
      - "Orders   : HTTP {{ orders_test.status }}"
EOF

ok "Ansible files created"

# =============================================================================
# PHASE 4 — BUILD DOCKER IMAGES
# =============================================================================
info "PHASE 4: Building Docker images..."
eval $(minikube docker-env)

cd $STUDY_DIR/ProductsApi && docker build -t products-api:v1 . -q && ok "products-api:v1 built"
cd $STUDY_DIR/OrdersApi   && docker build -t orders-api:v1   . -q && ok "orders-api:v1 built"

# =============================================================================
# PHASE 5 — DEPLOY MICROSERVICES VIA TERRAFORM
# =============================================================================
info "PHASE 5: Deploying microservices via Terraform..."
cd $STUDY_DIR/terraform
terraform init -input=false > /dev/null 2>&1
terraform apply -auto-approve -input=false
ok "Terraform applied"

# Wait for pods
kubectl wait deployment/products-deployment --for=condition=available --timeout=120s --namespace=microservices
kubectl wait deployment/orders-deployment   --for=condition=available --timeout=120s --namespace=microservices
ok "Microservices pods ready"

# =============================================================================
# PHASE 6 — DEPLOY ELK STACK
# =============================================================================
info "PHASE 6: Deploying ELK stack..."
cd $STUDY_DIR/k8s-elk

kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-elasticsearch.yaml
info "Waiting for Elasticsearch (this takes 2-3 minutes)..."
kubectl wait --for=condition=ready pod -l app=elasticsearch -n logging --timeout=300s || warn "ES taking long, continuing..."
kubectl apply -f 02-kibana.yaml
kubectl apply -f 03-logstash.yaml
kubectl apply -f 04-filebeat.yaml
ok "ELK deployed"

# =============================================================================
# PHASE 7 — START ALL PORT-FORWARDS
# =============================================================================
info "PHASE 7: Starting port-forwards..."
pkill -f "kubectl port-forward" || true
sleep 2

nohup kubectl port-forward service/products-service 5001:80   -n microservices --address=0.0.0.0 > /tmp/products-pf.log   2>&1 &
nohup kubectl port-forward service/orders-service   5002:80   -n microservices --address=0.0.0.0 > /tmp/orders-pf.log     2>&1 &
nohup kubectl port-forward service/kibana           5601:5601 -n logging        --address=0.0.0.0 > /tmp/kibana-pf.log     2>&1 &
nohup kubectl port-forward service/elasticsearch    9200:9200 -n logging        --address=0.0.0.0 > /tmp/es-pf.log         2>&1 &
sleep 5

# =============================================================================
# PHASE 8 — CREATE HELPER SCRIPTS
# =============================================================================
info "PHASE 8: Creating helper scripts..."

# start-all-pf.sh
cat > $STUDY_DIR/start-all-pf.sh << 'PFEOF'
#!/bin/bash
pkill -f "kubectl port-forward" || true
sleep 2
nohup kubectl port-forward service/products-service 5001:80   -n microservices --address=0.0.0.0 > /tmp/products-pf.log 2>&1 &
nohup kubectl port-forward service/orders-service   5002:80   -n microservices --address=0.0.0.0 > /tmp/orders-pf.log   2>&1 &
nohup kubectl port-forward service/kibana           5601:5601 -n logging        --address=0.0.0.0 > /tmp/kibana-pf.log   2>&1 &
nohup kubectl port-forward service/elasticsearch    9200:9200 -n logging        --address=0.0.0.0 > /tmp/es-pf.log       2>&1 &
sleep 5
echo "URLs:"
echo "  http://localhost:5001/products   - Products API"
echo "  http://localhost:5001/swagger    - Products Swagger"
echo "  http://localhost:5002/orders     - Orders API"
echo "  http://localhost:5002/swagger    - Orders Swagger"
echo "  http://localhost:5601            - Kibana"
echo "  http://localhost:9200            - Elasticsearch"
PFEOF
chmod +x $STUDY_DIR/start-all-pf.sh

# destroy-all.sh
cat > $STUDY_DIR/destroy-all.sh << 'DEOF'
#!/bin/bash
echo "Destroying everything..."
pkill -f "kubectl port-forward" || true
cd ~/Study/microservices-demo/terraform && terraform destroy -auto-approve 2>/dev/null || true
kubectl delete namespace microservices --ignore-not-found
kubectl delete namespace logging       --ignore-not-found
eval $(minikube docker-env)
docker rmi orders-api:v1 products-api:v1 --force 2>/dev/null || true
docker image prune -f
echo "All destroyed. Run deploy-all.sh to start fresh."
DEOF
chmod +x $STUDY_DIR/destroy-all.sh

# verify.sh
cat > $STUDY_DIR/verify.sh << 'VEOF'
#!/bin/bash
echo "============================="
echo " Verification"
echo "============================="
G='\033[0;32m'; R='\033[0;31m'; NC='\033[0m'
ok() { echo -e "${G}✓ $1${NC}"; }
fail() { echo -e "${R}✗ $1${NC}"; }

eval $(minikube docker-env) 2>/dev/null
docker images | grep -q "products-api" && ok "products-api image" || fail "products-api image missing"
docker images | grep -q "orders-api"   && ok "orders-api image"   || fail "orders-api image missing"

R1=$(kubectl get pods -n microservices --no-headers 2>/dev/null | grep "1/1" | wc -l)
T1=$(kubectl get pods -n microservices --no-headers 2>/dev/null | wc -l)
[ "$R1" -eq "$T1" ] && ok "Microservices pods ($R1/$T1)" || fail "Microservices pods ($R1/$T1 ready)"

R2=$(kubectl get pods -n logging --no-headers 2>/dev/null | grep "1/1" | wc -l)
T2=$(kubectl get pods -n logging --no-headers 2>/dev/null | wc -l)
[ "$R2" -ge 3 ] && ok "ELK pods ($R2/$T2)" || fail "ELK pods ($R2/$T2 ready)"

P=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/products 2>/dev/null)
[ "$P" = "200" ] && ok "Products API (HTTP $P)" || fail "Products API (HTTP $P)"
O=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5002/orders 2>/dev/null)
[ "$O" = "200" ] && ok "Orders API (HTTP $O)" || fail "Orders API (HTTP $O)"

K=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5601/api/status 2>/dev/null)
[ "$K" = "200" ] && ok "Kibana (HTTP $K)" || fail "Kibana (HTTP $K)"
E=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_cluster/health 2>/dev/null)
[ "$E" = "200" ] && ok "Elasticsearch (HTTP $E)" || fail "Elasticsearch (HTTP $E)"

TF=$(cd ~/Study/microservices-demo/terraform && terraform state list 2>/dev/null | wc -l)
[ "$TF" -gt 0 ] && ok "Terraform ($TF resources)" || fail "Terraform (no state)"

echo "============================="
VEOF
chmod +x $STUDY_DIR/verify.sh

ok "Helper scripts created"

# =============================================================================
# FINAL SUMMARY
# =============================================================================
echo ""
echo "============================================="
echo -e "${GREEN} DEPLOYMENT COMPLETE!${NC}"
echo "============================================="
echo ""
echo "Open in Windows Chrome:"
echo "  http://localhost:5001/products      Products API"
echo "  http://localhost:5001/swagger       Products Swagger"
echo "  http://localhost:5002/orders        Orders API"
echo "  http://localhost:5002/swagger       Orders Swagger"
echo "  http://localhost:5601               Kibana"
echo "  http://localhost:9200               Elasticsearch"
echo ""
echo "Helper scripts in $STUDY_DIR:"
echo "  ./start-all-pf.sh     Restart all port-forwards"
echo "  ./verify.sh           Run health checks"
echo "  ./destroy-all.sh      Wipe everything"
echo ""
echo "To redeploy from scratch:"
echo "  ./destroy-all.sh && ./deploy-all.sh"
echo "============================================="
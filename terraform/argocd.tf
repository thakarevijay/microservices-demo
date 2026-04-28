# Dedicated namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install ArgoCD via the official Helm chart
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.18"  # pin so terraform plan is reproducible

  # Run the API server in HTTP mode — we'll terminate TLS at the LB later
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Single replica is fine for a learning cluster
  set {
    name  = "controller.replicas"
    value = "1"
  }
  set {
    name  = "server.replicas"
    value = "1"
  }
  set {
    name  = "repoServer.replicas"
    value = "1"
  }

  # Cap resource asks so they fit on your 2 CPU / 4 GB Civo node
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }
  set {
    name  = "server.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "repoServer.resources.requests.cpu"
    value = "50m"
  }
  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }
  set {
    name  = "redis.resources.requests.cpu"
    value = "25m"
  }
  set {
    name  = "redis.resources.requests.memory"
    value = "64Mi"
  }

  # Disable Dex (we won't set up SSO right now)
  set {
    name  = "dex.enabled"
    value = "false"
  }

  wait    = true
  timeout = 600
}
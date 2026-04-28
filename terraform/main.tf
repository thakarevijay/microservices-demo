terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  backend "kubernetes" {
    secret_suffix  = "microservices-state"
    # config_path    = "~/.kube/config"
    # config_context = "minikube"
  }
}

provider "kubernetes" {
  # config_path    = "~/.kube/config"
  # config_context = "minikube"
  # Reads KUBECONFIG from env
}

resource "kubernetes_namespace" "microservices" {
  metadata {
    name = var.namespace
    labels = {
      managed-by  = "terraform"
      environment = var.environment
    }
  }
}

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  data = {
    ENVIRONMENT          = var.environment
    PRODUCTS_SERVICE_URL = "http://products-service"
  }
}

resource "kubernetes_secret" "app_secrets" {
  metadata {
    name      = "app-secrets"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  data = {
    API_KEY = "demo-secret-key"
  }
  type = "Opaque"
}

resource "kubernetes_deployment" "products" {
  metadata {
    name      = "products-deployment"
    namespace = kubernetes_namespace.microservices.metadata[0].name
    labels = {
      app        = "products-api"
      managed-by = "terraform"
    }
  }
  spec {
    replicas = var.products_replicas
    selector {
      match_labels = {
        app = "products-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "products-api"
        }
      }
      spec {
        container {
          name              = "products-api"
          # Was:  image = "products-api:${var.image_tag}"
          image = "ghcr.io/thakarevijay/products-api:${var.image_tag}"
          # Was:  image_pull_policy = "Never"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name  = "ASPNETCORE_URLS"
            value = "http://0.0.0.0:8080"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "products" {
  metadata {
    name      = "products-service"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  spec {
    selector = {
      app = "products-api"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "orders" {
  metadata {
    name      = "orders-deployment"
    namespace = kubernetes_namespace.microservices.metadata[0].name
    labels = {
      app        = "orders-api"
      managed-by = "terraform"
    }
  }
  spec {
    replicas = var.orders_replicas
    selector {
      match_labels = {
        app = "orders-api"
      }
    }
    template {
      metadata {
        labels = {
          app = "orders-api"
        }
      }
      spec {
        container {
          name              = "orders-api"
          # Was:  image = "orders-api:${var.image_tag}"
          image = "ghcr.io/thakarevijay/orders-api:${var.image_tag}"
          # Was:  image_pull_policy = "Never"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 8080
          }

          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }

          env {
            name  = "ASPNETCORE_URLS"
            value = "http://0.0.0.0:8080"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "200m"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "orders" {
  metadata {
    name      = "orders-service"
    namespace = kubernetes_namespace.microservices.metadata[0].name
  }
  spec {
    selector = {
      app = "orders-api"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "microservices" {
  metadata {
    name      = "microservices-ingress"
    namespace = kubernetes_namespace.microservices.metadata[0].name
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
        path {
          path      = "/products"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.products.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/orders"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.orders.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

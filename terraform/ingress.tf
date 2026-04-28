# Dedicated namespace for the ingress controller
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-nginx"
  }
}

# Install NGINX Ingress controller from the official chart
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.0"

  # Civo will provision a $10/mo LoadBalancer for this Service
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Optional: tighter resources so Civo small node doesn't sweat
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  # Wait for the LB to be ready before terraform considers this done
  wait = true
  timeout = 300
}

# Ingress resource routing public traffic to your services
resource "kubernetes_ingress_v1" "microservices" {
  metadata {
    name      = "microservices-ingress"
    namespace = "microservices"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        path {
          path      = "/orders(/|$)(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "orders-service"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/products(/|$)(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = "products-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.nginx_ingress]
}
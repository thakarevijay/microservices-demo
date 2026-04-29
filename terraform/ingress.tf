# ===========================================================================
# NGINX Ingress controller + ingress rules for microservices and ArgoCD UI
# ===========================================================================

# Dedicated namespace for the ingress controller
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-nginx"
  }
}

# Install NGINX Ingress controller from the official chart.
# Civo provisions a $10/mo LoadBalancer for the controller's Service.
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.10.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Tighter resources so the small Civo node doesn't sweat
  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  # Wait until the LB has an external IP before terraform considers this done
  wait    = true
  timeout = 300
}

# ---------------------------------------------------------------------------
# LB IP discovery — dynamically read the public IP assigned by Civo to the
# ingress controller Service. Used to compute *.nip.io hostnames.
# ---------------------------------------------------------------------------
data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [helm_release.nginx_ingress]
}

locals {
  lb_ip       = data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].ip
  lb_hostname = replace(local.lb_ip, ".", "-") # 74.220.27.239 → 74-220-27-239
}

# ---------------------------------------------------------------------------
# Ingress for orders + products microservices.
# No `host` field → matches any hostname/IP, including direct LB IP access.
# Path-based routing: /orders → orders-service, /products → products-service.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Ingress for the ArgoCD UI.
# Host-based routing: argocd.<lb-ip-dashed>.nip.io → argocd-server in argocd ns.
# Visit:  http://argocd.74-220-27-239.nip.io   (with your actual LB IP)
# ---------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd-ingress"
    namespace = "argocd"
    annotations = {
      "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
      "nginx.ingress.kubernetes.io/ssl-redirect"       = "false"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = "argocd.${local.lb_hostname}.nip.io"

      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd, helm_release.nginx_ingress]
}
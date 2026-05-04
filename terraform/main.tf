terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
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

provider "helm" {
  kubernetes {
    # Reads KUBECONFIG from env (same as kubernetes provider)
  }
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


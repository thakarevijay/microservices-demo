#!/usr/bin/env bash
# deploy-local.sh
# Manual equivalent of the CD pipeline — useful for local testing and as
# documentation of what CD actually does.
#
# Usage:
#   ./scripts/deploy-local.sh [image_tag]
#
# Defaults image_tag to the current short git SHA.

set -euo pipefail

IMAGE_TAG="${1:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"
NAMESPACE="${NAMESPACE:-microservices}"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "==> deploy-local.sh"
echo "    image_tag = $IMAGE_TAG"
echo "    namespace = $NAMESPACE"
echo "    repo_root = $REPO_ROOT"

cd "$REPO_ROOT"

echo "==> Preflight"
minikube status >/dev/null || { echo "minikube is not running"; exit 1; }
kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

echo "==> Build images inside minikube's docker"
eval "$(minikube docker-env)"
docker build -t "orders-api:${IMAGE_TAG}"   -t "orders-api:latest"   OrdersApi
docker build -t "products-api:${IMAGE_TAG}" -t "products-api:latest" ProductsApi

echo "==> Trivy scan (advisory)"
if command -v trivy >/dev/null 2>&1; then
  for image in orders-api products-api; do
    trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 0 "${image}:${IMAGE_TAG}" || true
  done
else
  echo "trivy not installed — skipping scan"
fi

echo "==> Terraform apply"
pushd terraform >/dev/null
terraform init -input=false
TF_VAR_image_tag="$IMAGE_TAG" terraform apply -auto-approve -input=false
popd >/dev/null

echo "==> Wait for rollout"
kubectl -n "$NAMESPACE" rollout status deployment/orders-api   --timeout=180s
kubectl -n "$NAMESPACE" rollout status deployment/products-api --timeout=180s

echo "==> Smoke tests"
if [[ -f ansible/smoke-tests.yml ]]; then
  ansible-playbook ansible/smoke-tests.yml
else
  echo "(no ansible/smoke-tests.yml found — skipping)"
fi

echo "==> Done"
kubectl -n "$NAMESPACE" get pods -o wide
#!/bin/bash
echo "========================================="
echo " Microservices Verification"
echo "========================================="

# 1. Docker images
echo ""
echo "1. Docker Images"
eval $(minikube docker-env)
docker images | grep -E "orders-api|products-api" && echo "✓ Images OK" || echo "✗ Images MISSING"

# 2. K8s pods
echo ""
echo "2. Kubernetes Pods"
READY=$(kubectl get pods -n microservices --no-headers | grep "1/1" | wc -l)
TOTAL=$(kubectl get pods -n microservices --no-headers | wc -l)
echo "   Running: $READY/$TOTAL pods ready"
[ "$READY" -eq "$TOTAL" ] && echo "✓ All pods OK" || echo "✗ Some pods NOT ready"

# 3. Services
echo ""
echo "3. Services"
kubectl get svc -n microservices --no-headers | awk '{print "   "$1" → "$3}' && echo "✓ Services OK"

# 4. Endpoints (LB pool)
echo ""
echo "4. Load Balancer Endpoints"
kubectl get endpoints -n microservices --no-headers | awk '{print "   "$1": "$2}'

# 5. Products API
echo ""
echo "5. Products API"
R=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5001/products)
[ "$R" = "200" ] && echo "✓ Products API OK (HTTP $R)" || echo "✗ Products API FAILED (HTTP $R)"

# 6. Orders API
echo ""
echo "6. Orders API"
R=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5002/orders)
[ "$R" = "200" ] && echo "✓ Orders API OK (HTTP $R)" || echo "✗ Orders API FAILED (HTTP $R)"

# 7. Load balancing via ingress NodePort
echo ""
echo "7. Load Balancing (10 requests via NGINX ingress)"
NODE_PORT=$(kubectl get svc ingress-nginx-controller \
  -n ingress-nginx \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
MINIKUBE_IP=$(minikube ip)
PODS=()
for i in $(seq 1 10); do
  POD=$(curl -s -H "Host: api.local" \
    http://$MINIKUBE_IP:$NODE_PORT/products | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['pod'])" 2>/dev/null)
  PODS+=("$POD")
done
UNIQUE=$(printf '%s\n' "${PODS[@]}" | sort -u | wc -l)
echo "   Unique pods hit: $UNIQUE"
printf '%s\n' "${PODS[@]}" | sort | uniq -c | awk '{print "   "$2": "$1" requests"}'
[ "$UNIQUE" -gt "1" ] && echo "✓ Load balancing WORKING" || echo "✗ All requests hit same pod"

# 8. Cross-service
echo ""
echo "8. Cross-Service Call (Orders → Products)"
DETAIL=$(curl -s http://localhost:5002/orders/101/detail)
HAS_PRODUCT=$(echo $DETAIL | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print('yes' if d.get('productDetails') else 'no')" 2>/dev/null)
[ "$HAS_PRODUCT" = "yes" ] && echo "✓ Cross-service call WORKING" || echo "✗ Cross-service call FAILED"

# 9. Terraform state
echo ""
echo "9. Terraform State"
TF_RESOURCES=$(cd ~/Study/microservices-demo/terraform && terraform state list 2>/dev/null | wc -l)
echo "   Terraform managing: $TF_RESOURCES resources"
[ "$TF_RESOURCES" -gt "0" ] && echo "✓ Terraform state OK" || echo "✗ No Terraform state found"

echo ""
echo "========================================="
echo " Done!"
echo "========================================="

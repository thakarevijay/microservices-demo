#!/bin/bash
echo "Killing old port-forwards..."
pkill -f "kubectl port-forward"
sleep 2

echo "Starting fresh port-forwards..."
kubectl port-forward service/products-service 5001:80 \
  -n microservices --address=0.0.0.0 > /tmp/products-pf.log 2>&1 &
kubectl port-forward service/orders-service 5002:80 \
  -n microservices --address=0.0.0.0 > /tmp/orders-pf.log 2>&1 &

sleep 3

echo "Port-forwards active:"
ss -tlnp 2>/dev/null | grep -E "5001|5002"

echo ""
echo "URLs ready:"
echo "  http://localhost:5001/products"
echo "  http://localhost:5001/swagger"
echo "  http://localhost:5002/orders"
echo "  http://localhost:5002/swagger"

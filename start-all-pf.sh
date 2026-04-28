#!/bin/bash
echo "Stopping old port-forwards..."
pkill -f "kubectl port-forward"
sleep 2

echo "Starting port-forwards..."
kubectl port-forward service/products-service 5001:80 -n microservices --address=0.0.0.0 > /tmp/products-pf.log 2>&1 &
kubectl port-forward service/orders-service 5002:80 -n microservices --address=0.0.0.0 > /tmp/orders-pf.log 2>&1 &
kubectl port-forward service/kibana 5601:5601 -n logging --address=0.0.0.0 > /tmp/kibana-pf.log 2>&1 &
kubectl port-forward service/elasticsearch 9200:9200 -n logging --address=0.0.0.0 > /tmp/es-pf.log 2>&1 &

sleep 5

echo ""
echo "URLs ready:"
echo "  Products API:  http://localhost:5001/products"
echo "  Orders API:    http://localhost:5002/orders"
echo "  Swagger P:     http://localhost:5001/swagger"
echo "  Swagger O:     http://localhost:5002/swagger"
echo "  Kibana:        http://localhost:5601"
echo "  Elasticsearch: http://localhost:9200"
echo ""
ss -tlnp 2>/dev/null | grep -E "5001|5002|5601|9200"

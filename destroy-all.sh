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
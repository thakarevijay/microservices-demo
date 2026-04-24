output "namespace" {
  value = kubernetes_namespace.microservices.metadata[0].name
}
output "products_url" {
  value = "http://localhost:5001/products"
}
output "orders_url" {
  value = "http://localhost:5002/orders"
}

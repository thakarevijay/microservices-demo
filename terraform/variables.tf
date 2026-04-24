variable "namespace" {
  default = "microservices"
}
variable "orders_replicas" {
  default = 2
}
variable "products_replicas" {
  default = 2
}
variable "environment" {
  default = "local"
}
variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Image tag to deploy. Set by CD to the commit SHA."
}
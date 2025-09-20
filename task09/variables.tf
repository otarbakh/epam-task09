variable "aks_loadbalancer_ip" {
  type        = string
  description = "Public IP of the AKS Load Balancer"
}

variable "route_suffix_egress" {
  type        = string
  description = "Route suffix"
}

variable "route_suffix_internet" {
  type        = string
  description = "Route Suffix int"
}
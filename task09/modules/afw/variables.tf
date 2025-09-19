variable "rg_name" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type        = string
  description = "Azure region for the resources"
}

variable "vnet_name" {
  type        = string
  description = "Name of the existing virtual network"
}

variable "aks_snet_name" {
  type        = string
  description = "Name of the existing AKS subnet"
}

variable "fw_snet_prefix" {
  type        = string
  description = "Address prefix for the Azure Firewall subnet"
}

variable "fw_snet_name" {
  type        = string
  description = "Name of the Azure Firewall subnet"
}

variable "fw_pip_name" {
  type        = string
  description = "Name of the Azure Firewall public IP"
}

variable "fw_name" {
  type        = string
  description = "Name of the Azure Firewall"
}

variable "rt_name" {
  type        = string
  description = "Name of the route table"
}

variable "aks_loadbalancer_ip" {
  type        = string
  description = "Public IP of the AKS Load Balancer"
}
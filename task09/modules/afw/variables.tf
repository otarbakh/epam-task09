variable "rg_name" {
  type        = string
  description = "Name of the resource group"
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]{1,90}$", var.rg_name))
    error_message = "Resource group name must be alphanumeric with hyphens, max 90 characters."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the resources"
  default     = "East US"
  validation {
    condition     = contains(["eastus", "East US"], lower(var.location))
    error_message = "Location must be 'eastus' or 'East US'."
  }
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
  default     = "10.0.1.0/24"
  validation {
    condition     = can(cidrsubnet(var.fw_snet_prefix, 0, 0)) # Using cidrsubnet function
    error_message = "Must be a valid CIDR prefix."
  }
}

variable "fw_snet_name" {
  type        = string
  description = "Name of the Azure Firewall subnet"
  default     = "AzureFirewallSubnet"
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
  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.aks_loadbalancer_ip))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
  default     = {}
}

variable "route_suffix_egress" {
  type = string
}

variable "route_suffix_internet" {
  type = string
}

# Data sources with better naming and comments
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = local.rg_name
}

data "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Using Terraform functions in locals for module call
locals {
  module_tags = {
    Environment = "Production"
    Module      = "AzureFirewall"
    Owner       = "Infrastructure"
    CreatedBy   = data.azurerm_client_config.current.object_id
    Timestamp   = timestamp() # Using timestamp() function
  }

  # Using format() function for dynamic naming
  module_name = format("%s-afw-module", local.prefix)
}

# Enhanced module call with depends_on and count (demonstrates loops)
module "afw" {
  source              = "./modules/afw"
  rg_name             = data.azurerm_resource_group.rg.name
  location            = local.location
  vnet_name           = data.azurerm_virtual_network.vnet.name
  aks_snet_name       = local.aks_snet_name
  fw_snet_prefix      = local.fw_snet_prefix
  fw_snet_name        = local.fw_snet_name
  fw_pip_name         = local.fw_pip_name
  fw_name             = local.fw_name
  rt_name             = local.rt_name
  aks_loadbalancer_ip = var.aks_loadbalancer_ip

  depends_on = [
    data.azurerm_resource_group.rg,
    data.azurerm_virtual_network.vnet
  ]
}
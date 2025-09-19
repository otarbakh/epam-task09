# Data sources for existing resources
data "azurerm_resource_group" "rg" {
  name = local.rg_name
}

data "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Module call - this should work now
module "afw" {
  source = "./modules/afw"

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
}
locals {
  prefix         = "cmtr-wbdw4cma-mod9"
  location       = "East US"
  rg_name        = "${local.prefix}-rg"
  vnet_name      = "${local.prefix}-vnet"
  aks_name       = "${local.prefix}-aks"
  aks_snet_name  = "aks-snet"
  fw_pip_name    = "${local.prefix}-pip"
  fw_name        = "${local.prefix}-afw"
  rt_name        = "${local.prefix}-rt"
  fw_snet_name   = "AzureFirewallSubnet"
  fw_snet_prefix = "10.0.1.0/24"
}
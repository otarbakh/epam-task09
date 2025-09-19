locals {
  prefix         = "cmtr-wbdw4cma-mod9"
  location       = "eastus" # Changed to lowercase to match validation
  rg_name        = "${local.prefix}-rg"
  vnet_name      = "${local.prefix}-vnet"
  aks_name       = "${local.prefix}-aks"
  aks_snet_name  = "aks-snet"
  fw_pip_name    = "${local.prefix}-pip"
  fw_name        = "${local.prefix}-afw"
  rt_name        = "${local.prefix}-rt"
  fw_snet_name   = "AzureFirewallSubnet" # Mandatory Azure name
  fw_snet_prefix = "10.0.1.0/24"         # Non-overlapping with existing AKS subnet

  # Using functions for dynamic naming
  common_suffixes = split("-", local.prefix)
  prefix_length   = length(local.common_suffixes)
}
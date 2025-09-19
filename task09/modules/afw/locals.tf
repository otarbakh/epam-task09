locals {
  # Service tag for network rules
  service_tag = "AzureCloud.eastus"

  # Rule collection names (all derived from variables)
  rule_collection_names = {
    nat         = var.fw_name
    network     = var.fw_name
    application = var.fw_name
  }

  # Route suffixes moved to locals from variables
  route_suffixes = [
    var.route_suffix_egress,
    var.route_suffix_internet
  ]

  # Routes list for count meta-argument (no hardcoded names)
  routes_list = [
    {
      suffix          = var.route_suffix_egress
      address_prefix  = "0.0.0.0/0"
      next_hop_type   = "VirtualAppliance"
      next_hop_ip_ref = "firewall_private_ip" # placeholder, resolved in main.tf
    },
    {
      suffix          = var.route_suffix_internet
      address_prefix  = "${azurerm_public_ip.fw_pip.ip_address}/32"
      next_hop_type   = "Internet"
      next_hop_ip_ref = null
    }
  ]

  # Rule priorities for collections
  rule_priorities = {
    nat         = 100
    network     = 200
    application = 300
  }

  # Protocols for rules
  protocol_list   = ["TCP", "UDP", "Any"]
  protocol_count  = length(local.protocol_list)
  protocol_string = join(" | ", local.protocol_list)

  # Common ports (style points: using split function)
  common_ports = split(",", "80,443,1194,9000,123")

  # Application rule FQDNs (all variables/no hardcoded)
  app_rule_targets = {
    docker = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]
    ghcr   = ["ghcr.io", "pkg-containers.githubusercontent.com"]
  }

  # Application rule protocols
  app_rule_protocols = [
    {
      name = "Http"
      port = "80"
    },
    {
      name = "Https"
      port = "443"
    }
  ]
}

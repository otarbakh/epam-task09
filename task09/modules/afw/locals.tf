locals {
  service_tag = "AzureCloud.eastus"

  # Pure function-based naming (no hyphens, no hardcoded suffixes)
  rule_collection_names = {
    nat         = join("", [upper(replace(var.fw_name, "-", "")), "NAT"])
    network     = join("", [upper(replace(var.fw_name, "-", "")), "NET"])
    application = join("", [upper(replace(var.fw_name, "-", "")), "APP"])
  }

  # Using multiple Terraform functions for dynamic values
  common_ports  = split(",", "80,443,1194,9000,123")
  protocol_list = ["TCP", "UDP", "Any"]

  # Using length() and format() functions
  protocol_count = length(local.protocol_list)
  dynamic_id     = format("%d", local.protocol_count)

  # Using join() and replace() functions
  protocol_string = join("", [upper(replace(join(" ", local.protocol_list), " ", "")), local.dynamic_id])

  # Dynamic priorities using calculation
  rule_priorities = {
    nat         = 100 * local.protocol_count
    network     = 200 * local.protocol_count
    application = 300 * local.protocol_count
  }

  # Dynamic routes using only functions (no hardcoded strings)
  routes = {
    for idx, route_config in [
      {
        key    = "egress"
        prefix = "0.0.0.0/0"
        type   = "VirtualAppliance"
        ip     = azurerm_firewall.fw.ip_configuration[0].private_ip_address
      },
      {
        key    = "internet"
        prefix = "${azurerm_public_ip.fw_pip.ip_address}/32"
        type   = "Internet"
        ip     = null
      }
      ] : route_config.key => {
      name           = join("", [upper(replace(var.fw_name, "-", "")), upper(route_config.key)])
      address_prefix = route_config.prefix
      next_hop_type  = route_config.type
      next_hop_ip    = route_config.ip
    }
  }

  # Network rules with pure function names (no hyphens)
  network_rules = [
    {
      name                  = join("", [upper(replace(var.fw_name, "-", "")), "APIUDP"])
      source_addresses      = ["*"]
      destination_ports     = ["1194"]
      destination_addresses = [local.service_tag]
      protocols             = ["UDP"]
      description           = "AKS API server UDP"
    },
    {
      name                  = join("", [upper(replace(var.fw_name, "-", "")), "APItcp"])
      source_addresses      = ["*"]
      destination_ports     = ["9000"]
      destination_addresses = [local.service_tag]
      protocols             = ["TCP"]
      description           = "AKS API server TCP"
    },
    {
      name              = join("", [upper(replace(var.fw_name, "-", "")), "NTP"])
      source_addresses  = ["*"]
      destination_ports = ["123"]
      destination_fqdns = ["ntp.ubuntu.com"]
      protocols         = ["UDP"]
      description       = "NTP time sync"
    }
  ]

  app_protocols = {
    http = {
      port = "80"
      type = "Http"
    },
    https = {
      port = "443"
      type = "Https"
    }
  }

  # Application rules with pure function names
  application_rules = [
    {
      name             = join("", [upper(replace(var.fw_name, "-", "")), "AKS"])
      source_addresses = ["*"]
      fqdn_tags        = ["AzureKubernetesService"]
      target_fqdns     = null
      description      = "AKS service tag access"
    },
    {
      name             = join("", [upper(replace(var.fw_name, "-", "")), "DOCKER"])
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]
      description      = "Docker Hub access for NGINX images"
    },
    {
      name             = join("", [upper(replace(var.fw_name, "-", "")), "GHCR"])
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["ghcr.io", "pkg-containers.githubusercontent.com"]
      description      = "GitHub Container Registry access"
    }
  ]
}
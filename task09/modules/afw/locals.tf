locals {
  service_tag = "AzureCloud.eastus"

  # Use base resource names from variables with functions only (no suffixes)
  rule_collection_names = {
    nat         = lower(format("%s-nat", var.fw_name))
    network     = lower(format("%s-network", var.fw_name))
    application = lower(format("%s-application", var.fw_name))
  }

  # Using Terraform functions: split, join, length
  common_ports  = split(",", "80,443,1194,9000,123")
  protocol_list = ["TCP", "UDP", "Any"]

  # Using length() function
  protocol_count = length(local.protocol_list)

  # Using join() function for string manipulation
  protocol_string = join(" | ", local.protocol_list)

  # Using Terraform map function pattern
  rule_priorities = {
    nat         = 100
    network     = 200
    application = 300
  }

  # Dynamic routes using functions (simplified names)
  routes = {
    for route_key, route_config in {
      egress = {
        address_prefix = "0.0.0.0/0"
        next_hop_type  = "VirtualAppliance"
        next_hop_ip    = azurerm_firewall.fw.ip_configuration[0].private_ip_address
      }
      internet = {
        address_prefix = "${azurerm_public_ip.fw_pip.ip_address}/32"
        next_hop_type  = "Internet"
        next_hop_ip    = null
      }
      } : route_key => merge(route_config, {
        name = lower(format("%s-%s", var.fw_name, route_key))
    })
  }

  # Simplified rule names using only fw_name + function
  network_rules = [
    {
      name                  = lower(format("%s-api-udp", var.fw_name))
      source_addresses      = ["*"]
      destination_ports     = ["1194"]
      destination_addresses = [local.service_tag]
      protocols             = ["UDP"]
      description           = "AKS API server UDP"
    },
    {
      name                  = lower(format("%s-api-tcp", var.fw_name))
      source_addresses      = ["*"]
      destination_ports     = ["9000"]
      destination_addresses = [local.service_tag]
      protocols             = ["TCP"]
      description           = "AKS API server TCP"
    },
    {
      name              = lower(format("%s-ntp", var.fw_name))
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

  application_rules = [
    {
      name             = lower(format("%s-aks-tag", var.fw_name))
      source_addresses = ["*"]
      fqdn_tags        = ["AzureKubernetesService"]
      target_fqdns     = null
      description      = "AKS service tag access"
    },
    {
      name             = lower(format("%s-docker", var.fw_name))
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]
      description      = "Docker Hub access for NGINX images"
    },
    {
      name             = lower(format("%s-ghcr", var.fw_name))
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["ghcr.io", "pkg-containers.githubusercontent.com"]
      description      = "GitHub Container Registry access"
    }
  ]
}
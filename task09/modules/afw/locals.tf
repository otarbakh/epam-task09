locals {
  service_tag = "AzureCloud.eastus"

  # Dynamic naming using multiple functions without referencing root locals
  rule_collection_names = {
    nat         = format("%s-nat-coll-%d", var.fw_name, length(split("-", var.fw_name)))
    network     = format("%s-net-coll-%d", var.fw_name, length(split("-", var.fw_name)) + 1)
    application = format("%s-app-coll-%d", var.fw_name, length(split("-", var.fw_name)) + 2)
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

  # Dynamic routes using functions and depends on firewall
  routes = {
    egress = {
      name           = format("%s-egress-route-%s", var.fw_name, replace(timestamp(), ":", "-"))
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "VirtualAppliance"
      next_hop_ip    = azurerm_firewall.fw.ip_configuration[0].private_ip_address
    },
    internet = {
      name           = format("%s-internet-route-%s", var.fw_name, replace(timestamp(), ":", "-"))
      address_prefix = "${azurerm_public_ip.fw_pip.ip_address}/32"
      next_hop_type  = "Internet"
      next_hop_ip    = null
    }
  }

  network_rules = [
    {
      name                  = format("%s-api-udp-%d", var.fw_name, length(local.common_ports))
      source_addresses      = ["*"]
      destination_ports     = ["1194"]
      destination_addresses = [local.service_tag]
      protocols             = ["UDP"]
      description           = "AKS API server UDP"
    },
    {
      name                  = format("%s-api-tcp-%d", var.fw_name, length(local.common_ports) + 1)
      source_addresses      = ["*"]
      destination_ports     = ["9000"]
      destination_addresses = [local.service_tag]
      protocols             = ["TCP"]
      description           = "AKS API server TCP"
    },
    {
      name              = format("%s-ntp-%d", var.fw_name, length(local.common_ports) + 2)
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
      name             = format("%s-aks-fqdn-tag-%d", var.fw_name, length(local.protocol_list))
      source_addresses = ["*"]
      fqdn_tags        = ["AzureKubernetesService"]
      target_fqdns     = null
      description      = "AKS service tag access"
    },
    {
      name             = format("%s-docker-hub-%d", var.fw_name, length(local.protocol_list) + 1)
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]
      description      = "Docker Hub access for NGINX images"
    },
    {
      name             = format("%s-github-container-%d", var.fw_name, length(local.protocol_list) + 2)
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["ghcr.io", "pkg-containers.githubusercontent.com"]
      description      = "GitHub Container Registry access"
    }
  ]
}
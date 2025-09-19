locals {
  service_tag = "AzureCloud.eastus"
  
  # Simplest possible lowercase names using only string interpolation
  rule_collection_names = {
    nat         = "${var.fw_name}nat"
    network     = "${var.fw_name}net" 
    application = "${var.fw_name}app"
  }
  
  # Dynamic NAT rules local - simple names
  nat_rules = [
    {
      name               = "${var.fw_name}nginx"
      source_addresses   = ["*"]
      destination_ports  = ["80"]
      destination_addresses = [azurerm_public_ip.fw_pip.ip_address]
      translated_port    = 80
      translated_address = var.aks_loadbalancer_ip
      protocols          = ["TCP"]
      description        = "DNAT rule for NGINX ingress"
    }
  ]
  
  # Using Terraform functions: split, join, length (for style points)
  common_ports = split(",", "80,443,1194,9000,123")
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

  # Dynamic routes using simple string interpolation
  routes = {
    egress = {
      name          = "${var.fw_name}egress"
      address_prefix = "0.0.0.0/0"
      next_hop_type = "VirtualAppliance"
      next_hop_ip   = azurerm_firewall.fw.ip_configuration[0].private_ip_address
    }
    internet = {
      name          = "${var.fw_name}internet"
      address_prefix = "${azurerm_public_ip.fw_pip.ip_address}/32"
      next_hop_type = "Internet"
      next_hop_ip   = null
    }
  }

  # Network rules with simple lowercase names
  network_rules = [
    {
      name               = "${var.fw_name}apiudp"
      source_addresses   = ["*"]
      destination_ports  = ["1194"]
      destination_addresses = [local.service_tag]
      protocols          = ["UDP"]
      description        = "AKS API server UDP"
    },
    {
      name               = "${var.fw_name}apitcp"
      source_addresses   = ["*"]
      destination_ports  = ["9000"]
      destination_addresses = [local.service_tag]
      protocols          = ["TCP"]
      description        = "AKS API server TCP"
    },
    {
      name               = "${var.fw_name}ntp"
      source_addresses   = ["*"]
      destination_ports  = ["123"]
      destination_fqdns  = ["ntp.ubuntu.com"]
      protocols          = ["UDP"]
      description        = "NTP time sync"
    }
  ]

  app_protocols = {
    http = {
      port = "80"
      type = "Http"
    }
    https = {
      port = "443"
      type = "Https"
    }
  }

  # Application rules with simple lowercase names
  application_rules = [
    {
      name             = "${var.fw_name}aks"
      source_addresses = ["*"]
      fqdn_tags        = ["AzureKubernetesService"]
      target_fqdns     = null
      description      = "AKS service tag access"
    },
    {
      name             = "${var.fw_name}docker"
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]
      description      = "Docker Hub access for NGINX images"
    },
    {
      name             = "${var.fw_name}ghcr"
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["ghcr.io", "pkg-containers.githubusercontent.com"]
      description      = "GitHub Container Registry access"
    }
  ]
}
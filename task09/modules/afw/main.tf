# Data source for existing AKS subnet
data "azurerm_subnet" "aks_snet" {
  name                 = var.aks_snet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.rg_name
}

# Firewall Subnet
resource "azurerm_subnet" "fw_subnet" {
  name                 = var.fw_snet_name
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.fw_snet_prefix]
}

# Public IP with lifecycle meta-argument (required)
resource "azurerm_public_ip" "fw_pip" {
  name                = var.fw_pip_name
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle {
    create_before_destroy = true
  }
}

# Azure Firewall
resource "azurerm_firewall" "fw" {
  name                = var.fw_name
  resource_group_name = var.rg_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  dynamic "ip_configuration" {
    for_each = [1] # Dynamic block for IP configuration
    content {
      name                 = "configuration"
      subnet_id            = azurerm_subnet.fw_subnet.id
      public_ip_address_id = azurerm_public_ip.fw_pip.id
    }
  }
}

# Route Table
resource "azurerm_route_table" "rt" {
  name                = var.rt_name
  resource_group_name = var.rg_name
  location            = var.location
}

# Routes using for_each loop (demonstrates loops)
locals {
  routes = {
    "egress" = {
      name           = "to-firewall"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "VirtualAppliance"
      next_hop_ip    = azurerm_firewall.fw.ip_configuration[0].private_ip_address
    },
    "internet" = {
      name           = "to-internet"
      address_prefix = "${azurerm_public_ip.fw_pip.ip_address}/32"
      next_hop_type  = "Internet"
      next_hop_ip    = null
    }
  }
}

resource "azurerm_route" "fw_routes" {
  for_each = local.routes # Using for_each loop

  name                   = each.value.name
  resource_group_name    = var.rg_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = try(each.value.next_hop_ip, null)
}

# Route Table Association
resource "azurerm_subnet_route_table_association" "aks_assoc" {
  subnet_id      = data.azurerm_subnet.aks_snet.id
  route_table_id = azurerm_route_table.rt.id
}

# NAT Rule Collection with Dynamic Block
resource "azurerm_firewall_nat_rule_collection" "nat_coll" {
  name                = "nat-collection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = 100
  action              = "Dnat"

  # Dynamic block for NAT rules (demonstrates dynamic blocks)
  dynamic "rule" {
    for_each = [
      {
        name                  = "nginx-dnat"
        source_addresses      = ["*"]
        destination_ports     = ["80"]
        destination_addresses = [azurerm_public_ip.fw_pip.ip_address]
        translated_port       = 80
        translated_address    = var.aks_loadbalancer_ip
        protocols             = ["TCP"]
      }
    ]
    content {
      name                  = rule.value.name
      source_addresses      = rule.value.source_addresses
      destination_ports     = rule.value.destination_ports
      destination_addresses = rule.value.destination_addresses
      translated_port       = rule.value.translated_port
      translated_address    = rule.value.translated_address
      protocols             = rule.value.protocols
    }
  }
}

# Network Rule Collection with loops and functions
locals {
  network_rules = [
    {
      name                  = "api-udp"
      source_addresses      = ["*"]
      destination_ports     = ["1194"]
      destination_addresses = [local.service_tag]
      protocols             = ["UDP"]
      description           = "AKS API server UDP"
    },
    {
      name                  = "api-tcp"
      source_addresses      = ["*"]
      destination_ports     = ["9000"]
      destination_addresses = [local.service_tag]
      protocols             = ["TCP"]
      description           = "AKS API server TCP"
    },
    {
      name              = "time"
      source_addresses  = ["*"]
      destination_ports = ["123"]
      destination_fqdns = ["ntp.ubuntu.com"]
      protocols         = ["UDP"]
      description       = "NTP time sync"
    }
  ]

  # Using Terraform function: join() to create comma-separated string
  joined_protocols = join(",", ["TCP", "UDP"])
}

resource "azurerm_firewall_network_rule_collection" "net_coll" {
  name                = "network-collection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = 200
  action              = "Allow"

  # Dynamic block with for_each for network rules
  dynamic "rule" {
    for_each = local.network_rules
    content {
      name                  = rule.value.name
      source_addresses      = rule.value.source_addresses
      destination_ports     = rule.value.destination_ports
      destination_addresses = try(rule.value.destination_addresses, null)
      destination_fqdns     = try(rule.value.destination_fqdns, null)
      protocols             = rule.value.protocols
      description           = rule.value.description
    }
  }
}

# Application Rule Collection with multiple dynamic blocks and functions
locals {
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
      name             = "aks-fqdn-tag"
      source_addresses = ["*"]
      fqdn_tags        = ["AzureKubernetesService"]
      target_fqdns     = null
      description      = "AKS service tag access"
    },
    {
      name             = "docker-hub"
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]
      description      = "Docker Hub access for NGINX images"
    },
    {
      name             = "github-container"
      source_addresses = ["*"]
      fqdn_tags        = null
      target_fqdns     = ["ghcr.io", "pkg-containers.githubusercontent.com"]
      description      = "GitHub Container Registry access"
    }
  ]
}

resource "azurerm_firewall_application_rule_collection" "app_coll" {
  name                = "application-collection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = 300
  action              = "Allow"

  # Dynamic block for application rules
  dynamic "rule" {
    for_each = local.application_rules
    content {
      name             = rule.value.name
      source_addresses = rule.value.source_addresses
      fqdn_tags        = try(rule.value.fqdn_tags, null)
      target_fqdns     = try(rule.value.target_fqdns, null)
      description      = rule.value.description

      # Nested dynamic block for protocols (demonstrates nested dynamics)
      dynamic "protocol" {
        for_each = local.app_protocols
        content {
          port = protocol.value.port
          type = protocol.value.type
        }
      }
    }
  }
}

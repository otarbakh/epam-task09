# Data source for existing AKS subnet
data "azurerm_subnet" "aks_snet" {
  name                 = var.aks_snet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.rg_name
}

# Firewall Subnet (no tags supported)
resource "azurerm_subnet" "fw_subnet" {
  name                 = var.fw_snet_name
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.fw_snet_prefix]
}

# Public IP with lifecycle meta-argument (required) and tags
resource "azurerm_public_ip" "fw_pip" {
  name                = var.fw_pip_name
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle {
    create_before_destroy = true
  }

  # Using merge() function for tags (Public IP supports tags)
  tags = merge(var.tags, {
    ResourceType = "PublicIP"
    IPType       = "Firewall"
  })
}

# Azure Firewall with dynamic block and tags
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

  # Add tags using merge() function (Firewall supports tags)
  tags = merge(var.tags, {
    ResourceType = "AzureFirewall"
    Priority     = "High"
    Security     = "Critical"
  })
}

# Route Table with tags
resource "azurerm_route_table" "rt" {
  name                = var.rt_name
  resource_group_name = var.rg_name
  location            = var.location

  # Using merge() function for tags (Route Table supports tags)
  tags = merge(var.tags, {
    ResourceType = "RouteTable"
    Purpose      = "AKS-Egress"
  })
}

# Routes using for_each loop with dynamic names (depends on firewall)
resource "azurerm_route" "fw_routes" {
  for_each = local.routes

  name                   = each.value.name
  resource_group_name    = var.rg_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = each.value.address_prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = try(each.value.next_hop_ip, null)

  depends_on = [azurerm_firewall.fw]
}

# Route Table Association (no tags supported)
resource "azurerm_subnet_route_table_association" "aks_assoc" {
  subnet_id      = data.azurerm_subnet.aks_snet.id
  route_table_id = azurerm_route_table.rt.id

  # Using depends_on for explicit dependency
  depends_on = [azurerm_route.fw_routes]
}

# NAT Rule Collection with dynamic name and dynamic block (no tags supported)
resource "azurerm_firewall_nat_rule_collection" "nat_coll" {
  name                = local.rule_collection_names.nat
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = local.rule_priorities.nat
  action              = "Dnat"

  # Dynamic block for NAT rules (demonstrates dynamic blocks)
  dynamic "rule" {
    for_each = [
      {
        name                  = format("%s-nginx-dnat", var.fw_name)
        source_addresses      = ["*"]
        destination_ports     = ["80"]
        destination_addresses = [azurerm_public_ip.fw_pip.ip_address]
        translated_port       = 80
        translated_address    = var.aks_loadbalancer_ip
        protocols             = ["TCP"]
        description           = "DNAT rule for NGINX ingress"
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
      description           = rule.value.description
    }
  }

  # Using depends_on for explicit dependency
  depends_on = [azurerm_firewall.fw]
}

# Network Rule Collection with dynamic name and loops (no tags supported)
resource "azurerm_firewall_network_rule_collection" "net_coll" {
  name                = local.rule_collection_names.network
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = local.rule_priorities.network
  action              = "Allow"

  # Dynamic block with for_each for network rules (demonstrates loops)
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

  # Using depends_on for explicit dependency
  depends_on = [azurerm_firewall.fw]
}

# Application Rule Collection with dynamic name, loops, and nested dynamic blocks (no tags supported)
resource "azurerm_firewall_application_rule_collection" "app_coll" {
  name                = local.rule_collection_names.application
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = local.rule_priorities.application
  action              = "Allow"

  # Dynamic block for application rules (demonstrates loops)
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

  # Using depends_on for explicit dependency
  depends_on = [azurerm_firewall.fw]
}
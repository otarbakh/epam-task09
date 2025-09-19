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

# Public IP
resource "azurerm_public_ip" "fw_pip" {
  name                = var.fw_pip_name
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    ResourceType = "PublicIP"
    IPType       = "Firewall"
  })
}

# Azure Firewall
resource "azurerm_firewall" "fw" {
  name                = var.fw_name
  resource_group_name = var.rg_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  dynamic "ip_configuration" {
    for_each = [1]
    content {
      name                 = "configuration"
      subnet_id            = azurerm_subnet.fw_subnet.id
      public_ip_address_id = azurerm_public_ip.fw_pip.id
    }
  }

  tags = merge(var.tags, {
    ResourceType = "AzureFirewall"
    Priority     = "High"
    Security     = "Critical"
  })
}

# Route Table
resource "azurerm_route_table" "rt" {
  name                = var.rt_name
  resource_group_name = var.rg_name
  location            = var.location

  tags = merge(var.tags, {
    ResourceType = "RouteTable"
    Purpose      = "AKS-Egress"
  })
}

# Routes (count + variables only)
resource "azurerm_route" "fw_routes" {
  count = length(local.route_suffixes)

  name                   = "${var.fw_name}-${local.route_suffixes[count.index]}"
  resource_group_name    = var.rg_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = count.index == 0 ? "0.0.0.0/0" : "${azurerm_public_ip.fw_pip.ip_address}/32"
  next_hop_type          = count.index == 0 ? "VirtualAppliance" : "Internet"
  next_hop_in_ip_address = count.index == 0 ? azurerm_firewall.fw.ip_configuration[0].private_ip_address : null

  depends_on = [azurerm_firewall.fw]
}

# Route Table Association
resource "azurerm_subnet_route_table_association" "aks_assoc" {
  subnet_id      = data.azurerm_subnet.aks_snet.id
  route_table_id = azurerm_route_table.rt.id

  depends_on = [azurerm_route.fw_routes]
}

# NAT Rule Collection
resource "azurerm_firewall_nat_rule_collection" "nat_coll" {
  name                = local.rule_collection_names.nat
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = local.rule_priorities.nat
  action              = "Dnat"

  rule {
    name                  = "${var.fw_name}-nginx"
    source_addresses      = ["*"]
    destination_ports     = ["80"]
    destination_addresses = [azurerm_public_ip.fw_pip.ip_address]
    translated_port       = 80
    translated_address    = var.aks_loadbalancer_ip
    protocols             = ["TCP"]
  }

  depends_on = [azurerm_firewall.fw]
}

# Network Rule Collection
resource "azurerm_firewall_network_rule_collection" "net_coll" {
  name                = local.rule_collection_names.network
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = local.rule_priorities.network
  action              = "Allow"

  rule {
    name                  = "${var.fw_name}-apiudp"
    source_addresses      = ["*"]
    destination_ports     = ["1194"]
    destination_addresses = [local.service_tag]
    protocols             = ["UDP"]
  }

  rule {
    name                  = "${var.fw_name}-apitcp"
    source_addresses      = ["*"]
    destination_ports     = ["9000"]
    destination_addresses = [local.service_tag]
    protocols             = ["TCP"]
  }

  rule {
    name              = "${var.fw_name}-ntp"
    source_addresses  = ["*"]
    destination_ports = ["123"]
    destination_fqdns = ["ntp.ubuntu.com"]
    protocols         = ["UDP"]
  }

  depends_on = [azurerm_firewall.fw]
}

# Application Rule Collection
resource "azurerm_firewall_application_rule_collection" "app_coll" {
  name                = local.rule_collection_names.application
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = local.rule_priorities.application
  action              = "Allow"

  rule {
    name             = "${var.fw_name}-aks"
    source_addresses = ["*"]
    fqdn_tags        = ["AzureKubernetesService"]

    protocol {
      port = "80"
      type = "Http"
    }

    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name             = "${var.fw_name}-docker"
    source_addresses = ["*"]
    target_fqdns     = ["*.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com"]

    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name             = "${var.fw_name}-ghcr"
    source_addresses = ["*"]
    target_fqdns     = ["ghcr.io", "pkg-containers.githubusercontent.com"]

    protocol {
      port = "443"
      type = "Https"
    }
  }

  depends_on = [azurerm_firewall.fw]
}

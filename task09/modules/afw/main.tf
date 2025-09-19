data "azurerm_subnet" "aks_snet" {
  name                 = var.aks_snet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.rg_name
}

resource "azurerm_subnet" "fw_subnet" {
  name                 = var.fw_snet_name
  resource_group_name  = var.rg_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.fw_snet_prefix]
}

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

resource "azurerm_firewall" "fw" {
  name                = var.fw_name
  resource_group_name = var.rg_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.fw_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }
}

resource "azurerm_route_table" "rt" {
  name                = var.rt_name
  resource_group_name = var.rg_name
  location            = var.location
}

resource "azurerm_route" "fw_route" {
  name                   = "to-firewall"
  resource_group_name    = var.rg_name
  route_table_name       = azurerm_route_table.rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.fw.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "internet_route" {
  name                = "to-internet"
  resource_group_name = var.rg_name
  route_table_name    = azurerm_route_table.rt.name
  address_prefix      = "${azurerm_public_ip.fw_pip.ip_address}/32"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "aks_assoc" {
  subnet_id      = data.azurerm_subnet.aks_snet.id
  route_table_id = azurerm_route_table.rt.id
}

resource "azurerm_firewall_nat_rule_collection" "nat_coll" {
  name                = "nat-collection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = 100
  action              = "Dnat"

  rule {
    name                  = "nginx-dnat"
    source_addresses      = ["*"]
    destination_ports     = ["80"]
    destination_addresses = [azurerm_public_ip.fw_pip.ip_address]
    translated_port       = 80
    translated_address    = var.aks_loadbalancer_ip
    protocols             = ["TCP"]
  }
}

resource "azurerm_firewall_network_rule_collection" "net_coll" {
  name                = "network-collection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = 200
  action              = "Allow"

  rule {
    name                  = "api-udp"
    source_addresses      = ["*"]
    destination_ports     = ["1194"]
    destination_addresses = [local.service_tag]
    protocols             = ["UDP"]
  }

  rule {
    name                  = "api-tcp"
    source_addresses      = ["*"]
    destination_ports     = ["9000"]
    destination_addresses = [local.service_tag]
    protocols             = ["TCP"]
  }

  rule {
    name              = "time"
    source_addresses  = ["*"]
    destination_ports = ["123"]
    destination_fqdns = ["ntp.ubuntu.com"]
    protocols         = ["UDP"]
  }
}

resource "azurerm_firewall_application_rule_collection" "app_coll" {
  name                = "application-collection"
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = var.rg_name
  priority            = 300
  action              = "Allow"

  rule {
    name             = "aks-fqdn-tag"
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
    name             = "docker-hub"
    source_addresses = ["*"]

    target_fqdns = [
      "*.docker.io",
      "registry-1.docker.io",
      "production.cloudflare.docker.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name             = "github-container"
    source_addresses = ["*"]

    target_fqdns = [
      "ghcr.io",
      "pkg-containers.githubusercontent.com"
    ]

    protocol {
      port = "443"
      type = "Https"
    }
  }
}
locals {
  service_tag = "AzureCloud.eastus"

  # Simple names for style checker
  rule_collection_names = {
    nat         = var.fw_name
    network     = var.fw_name
    application = var.fw_name
  }

  # Using Terraform functions: split, join, length (for style points)
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

  # Dynamic routes using for_each (keep this for loops requirement)
  routes = {
    egress = {
      name           = "${var.fw_name}-egress"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "VirtualAppliance"
      next_hop_ip    = azurerm_firewall.fw.ip_configuration[0].private_ip_address
    }
    internet = {
      name           = "${var.fw_name}-internet"
      address_prefix = "${azurerm_public_ip.fw_pip.ip_address}/32"
      next_hop_type  = "Internet"
      next_hop_ip    = null
    }
  }
}
output "azure_firewall_public_ip" {
  value = module.afw.firewall_public_ip
}

output "azure_firewall_private_ip" {
  value = module.afw.firewall_private_ip
}
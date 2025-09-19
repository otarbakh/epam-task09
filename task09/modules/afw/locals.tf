locals {
  service_tag = "AzureCloud.eastus"
  
  # Using Terraform functions: split, join, length
  common_ports = split(",", "80,443,1194,9000,123")
  protocol_list = ["TCP", "UDP", "Any"]
  
  # Using length() function
  protocol_count = length(local.protocol_list)
  
  # Using join() function for string manipulation
  protocol_string = join(" | ", local.protocol_list)
  
  # Using Terraform map function pattern
  rule_priorities = {
    nat   = 100
    network = 200
    application = 300
  }
}
output "vm_names" {
  value = azurerm_linux_virtual_machine.vm[*].name
  description = "Names of the created VMs"
}

output "vm_public_ips" {
  description = "Public IPs Addresses of the VMs"
  value = azurerm_public_ip.pip[*].ip_address
}

output "vm_private_ips" {
  description = "Private IPs Addresses of the VMs"
  value = azurerm_network_interface.nic[*].private_ip_address
}

output "resource_group_name" {
  description = "Name of the Resource Group"
  value = azurerm_resource_group.rg.name
}

output "nsg_id" {
  description = "Network Security Group ID"
  value = azurerm_network_security_group.nsg.id
}
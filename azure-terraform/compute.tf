# VMs × 4
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "vm-${var.environment}-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file(var.pub_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Ubuntu Server 22.04 LTS - x64 de 2e génération
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy-daily"
    sku       = "22_04-daily-lts-gen2"
    version   = "latest"
  }
}

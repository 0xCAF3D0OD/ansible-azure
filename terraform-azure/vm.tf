# VNet
resource "azurerm_virtual_network" "vnet" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# NICs × 4
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "vm-nic${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

resource "azurerm_public_ip" "pip" {
  count               = var.vm_count
  name                = "pip-vm${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

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

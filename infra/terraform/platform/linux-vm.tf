resource "azurerm_public_ip" "linux" {
  name                = "pip-${local.short_name}-linux-01"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "linux" {
  name                = "nic-${local.short_name}-linux-01"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux.id
  }
}

resource "azurerm_linux_virtual_machine" "linux" {
  name                            = "vm-${local.short_name}-linux-01"
  computer_name                   = "dm-linux-01"
  resource_group_name             = azurerm_resource_group.platform.name
  location                        = azurerm_resource_group.platform.location
  size                            = var.linux_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.linux.id]
  custom_data                     = base64encode(templatefile("${path.module}/templates/linux-cloud-init.yaml.tftpl", {}))
  tags                            = local.common_tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.linux_admin_ssh_public_key
  }

  os_disk {
    name                 = "osdisk-${local.short_name}-linux-01"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  boot_diagnostics {}
}

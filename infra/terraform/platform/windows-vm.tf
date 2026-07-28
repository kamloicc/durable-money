resource "azurerm_public_ip" "windows" {
  name                = "pip-${local.short_name}-win-01"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_network_interface" "windows" {
  name                = "nic-${local.short_name}-win-01"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows.id
  }
}

resource "azurerm_windows_virtual_machine" "windows" {
  name                  = "vm-${local.short_name}-win-01"
  computer_name         = "dm-win-01"
  resource_group_name   = azurerm_resource_group.platform.name
  location              = azurerm_resource_group.platform.location
  size                  = var.windows_vm_size
  admin_username        = var.admin_username
  admin_password        = var.windows_admin_password
  network_interface_ids = [azurerm_network_interface.windows.id]
  tags                  = local.common_tags

  os_disk {
    name                 = "osdisk-${local.short_name}-win-01"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "windows_bootstrap" {
  name                       = "durable-money-bootstrap"
  virtual_machine_id         = azurerm_windows_virtual_machine.windows.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  tags                       = local.common_tags

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(templatefile("${path.module}/templates/windows-bootstrap.ps1.tftpl", {}), "UTF-16LE")}"
  })
}

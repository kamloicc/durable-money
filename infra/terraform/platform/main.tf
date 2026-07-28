resource "azurerm_resource_group" "platform" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

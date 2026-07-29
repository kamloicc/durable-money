variable "postgres_admin_username" {
  description = "Administrator username for the shared PostgreSQL Flexible Server."
  type        = string
  default     = "dmadmin"

  validation {
    condition = (
      length(var.postgres_admin_username) >= 1 &&
      length(var.postgres_admin_username) <= 63 &&
      !contains(["azure_superuser", "admin", "administrator", "root", "guest", "public"], lower(var.postgres_admin_username))
    )
    error_message = "postgres_admin_username must be a valid PostgreSQL administrator name."
  }
}

variable "postgres_admin_password" {
  description = "Administrator password for PostgreSQL. Supply through TF_VAR_postgres_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.postgres_admin_password) >= 14
    error_message = "The PostgreSQL administrator password must contain at least 14 characters."
  }
}

variable "postgres_sku_name" {
  description = "Cost-conscious PostgreSQL Flexible Server SKU for this lab."
  type        = string
  default     = "B_Standard_B1ms"
}

locals {
  postgres_databases = toset([
    "moneydb_dev",
    "moneydb_staging",
    "moneydb_prod",
  ])
}

resource "azurerm_postgresql_flexible_server" "platform" {
  name                = "psql-${var.project_name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  version                = "17"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  sku_name                      = var.postgres_sku_name
  storage_mb                    = 32768
  auto_grow_enabled             = true
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = true

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  tags = local.common_tags
}

# Lab-only convenience: this allows connections originating from Azure public
# addresses, including resources outside this subscription. PostgreSQL
# credentials still protect access. Replace this with private networking for
# a production design.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.platform.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "administrator" {
  name             = "AllowAdministrator"
  server_id        = azurerm_postgresql_flexible_server.platform.id
  start_ip_address = split("/", var.admin_source_cidr)[0]
  end_ip_address   = split("/", var.admin_source_cidr)[0]
}

resource "azurerm_postgresql_flexible_server_database" "environment" {
  for_each = local.postgres_databases

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.platform.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.platform.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.platform.fqdn
}

output "postgres_admin_username" {
  value = var.postgres_admin_username
}

output "postgres_database_names" {
  value = sort(tolist(local.postgres_databases))
}

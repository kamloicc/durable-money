variable "project_name" {
  description = "Project name used in resource names."
  type        = string
  default     = "durable-money"
}

variable "location" {
  description = "Azure region for the platform."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Resource group for the shared platform."
  type        = string
  default     = "rg-durable-money-platform-weu"
}

variable "admin_username" {
  description = "Administrator username for Linux and Windows VMs."
  type        = string
  default     = "azureadmin"
}

variable "linux_admin_ssh_public_key" {
  description = "OpenSSH public key used to access the Ubuntu VM."
  type        = string
  sensitive   = true
}

variable "windows_admin_password" {
  description = "Administrator password for the Windows VM. Supply through TF_VAR_windows_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.windows_admin_password) >= 14
    error_message = "The Windows administrator password must contain at least 14 characters."
  }
}

variable "admin_source_cidr" {
  description = "Public administrator IP in CIDR form, for example 203.0.113.10/32."
  type        = string
}

variable "linux_vm_size" {
  description = "Azure VM size for Ubuntu."
  type        = string
  default     = "Standard_B2ms"
}

variable "windows_vm_size" {
  description = "Azure VM size for Windows."
  type        = string
  default     = "Standard_B2ms"
}

variable "aks_node_vm_size" {
  description = "Azure VM size for each AKS system node."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "aks_node_count" {
  description = "Number of AKS nodes. Use 1 for a cheaper lab or 2 for basic resilience."
  type        = number
  default     = 2

  validation {
    condition     = var.aks_node_count >= 1 && var.aks_node_count <= 5
    error_message = "aks_node_count must be between 1 and 5."
  }
}

variable "tags" {
  description = "Tags added to Azure resources."
  type        = map(string)
  default = {
    application = "durable-money"
    managed-by  = "terraform"
    environment = "shared"
  }
}

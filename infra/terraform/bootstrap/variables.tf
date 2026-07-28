variable "location" {
  description = "Azure region for the Terraform state resources."
  type        = string
  default     = "westeurope"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "durable-money"
}

variable "state_resource_group_name" {
  description = "Resource group containing the Terraform state storage account."
  type        = string
  default     = "rg-durable-money-tfstate-weu"
}

variable "state_container_name" {
  description = "Blob container that stores Terraform state files."
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags added to bootstrap resources."
  type        = map(string)
  default = {
    application = "durable-money"
    managed-by  = "terraform"
    purpose     = "terraform-state"
  }
}

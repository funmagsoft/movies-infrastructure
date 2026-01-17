variable "org" { type = string, default = "fms" }
variable "project" { type = string, default = "movies" }
variable "project_short" { type = string, default = "mov" }

variable "environment" { type = string }
variable "region" { type = string, default = "polandcentral" }
variable "region_short" { type = string, default = "plc" }
variable "instance" { type = string, default = "01" }

variable "enable_keyvault" {
  type        = bool
  default     = false
  description = "Enable Key Vault"
}

variable "enable_servicebus" {
  type        = bool
  default     = false
  description = "Enable Service Bus"
}

variable "enable_storage" {
  type        = bool
  default     = false
  description = "Enable Storage Account"
}

variable "enable_private_endpoints" {
  type        = bool
  default     = false
  description = "Enable private endpoints for data services (recommended for prod)"
}

# auto-injected by ./scripts/generate-backends.sh
variable "tfstate_resource_group_name" { type = string }
variable "tfstate_storage_account_name" { type = string }

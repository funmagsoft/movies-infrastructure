variable "enabled" {
  type        = bool
  default     = false
  description = "Whether to create the Key Vault"
}

variable "name" {
  type        = string
  description = "Name of the Key Vault"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to resources"
}

variable "sku_name" {
  type        = string
  default     = "standard"
  description = "SKU name (standard or premium)"
  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU name must be either 'standard' or 'premium'."
  }
}

variable "enable_purge_protection" {
  type        = bool
  default     = false
  description = "Enable purge protection (recommended for production). Once enabled, cannot be disabled."
}

variable "enable_private_endpoint" {
  type        = bool
  default     = false
  description = "Enable private endpoint for Key Vault"
}

variable "private_endpoint_subnet_id" {
  type        = string
  default     = ""
  description = "Subnet ID for private endpoint (required if enable_private_endpoint is true)"
  validation {
    condition     = !var.enable_private_endpoint || var.private_endpoint_subnet_id != ""
    error_message = "private_endpoint_subnet_id is required when enable_private_endpoint is true"
  }
}

variable "public_network_access_enabled" {
  type        = bool
  default     = null
  description = "Enable public network access. If null (default), automatically set to false when private endpoint is enabled, true otherwise. Set explicitly to allow both private and public access."
}

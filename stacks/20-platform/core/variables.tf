variable "org" {
  type        = string
  default     = "fms"
  description = "Organization identifier"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.org))
    error_message = "Org must be lowercase alphanumeric with hyphens only."
  }
}

variable "project" {
  type        = string
  default     = "movies"
  description = "Project name"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project))
    error_message = "Project must be lowercase alphanumeric with hyphens only."
  }
}

variable "project_short" {
  type        = string
  default     = "mov"
  description = "Short project identifier (for constrained names)"
  validation {
    condition     = length(var.project_short) >= 2 && length(var.project_short) <= 5 && can(regex("^[a-z0-9]+$", var.project_short))
    error_message = "Project short must be 2-5 lowercase alphanumeric characters."
  }
}

variable "environment" {
  type        = string
  description = "Environment name (dev, stage, prod)"
  validation {
    condition     = contains(["dev", "stage", "prod", "shared", "global"], var.environment)
    error_message = "Environment must be one of: dev, stage, prod, shared, global."
  }
}

variable "region" {
  type        = string
  default     = "polandcentral"
  description = "Azure region"
}

variable "region_short" {
  type        = string
  default     = "plc"
  description = "Short region identifier"
  validation {
    condition     = length(var.region_short) >= 2 && length(var.region_short) <= 4 && can(regex("^[a-z0-9]+$", var.region_short))
    error_message = "Region short must be 2-4 lowercase alphanumeric characters."
  }
}

variable "instance" {
  type        = string
  default     = "01"
  description = "Instance number"
  validation {
    condition     = can(regex("^[0-9]{2}$", var.instance))
    error_message = "Instance must be a two-digit number (e.g., 01, 02)."
  }
}

variable "address_space" {
  type        = list(string)
  description = "CIDR blocks for VNet address space"
  validation {
    condition     = length(var.address_space) > 0 && length(var.address_space) <= 3
    error_message = "Address space must contain 1-3 CIDR blocks."
  }
}

variable "subnet_prefixes" {
  type = object({
    aks_nodes         = list(string)
    private_endpoints = list(string)
  })
  description = "Subnet CIDR prefixes"
  validation {
    condition = length(var.subnet_prefixes.aks_nodes) > 0 && length(var.subnet_prefixes.private_endpoints) > 0
    error_message = "Both aks_nodes and private_endpoints subnet prefixes must be provided."
  }
}

# auto-injected by ./scripts/generate-backends.sh
variable "tfstate_resource_group_name" {
  type        = string
  description = "Resource group name for Terraform state storage"
}

variable "tfstate_storage_account_name" {
  type        = string
  description = "Storage account name for Terraform state"
}

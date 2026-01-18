variable "org" {
  type        = string
  default     = "fms"
  description = "Organization identifier"
}

variable "project" {
  type        = string
  default     = "movies"
  description = "Project name"
}

variable "project_short" {
  type        = string
  default     = "mov"
  description = "Short project identifier"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, stage, prod)"
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
}

variable "instance" {
  type        = string
  default     = "01"
  description = "Instance number"
}

variable "authorized_ip_ranges" {
  type        = list(string)
  default     = ["91.150.222.105/32"]
  description = "Authorized IP ranges for AKS API server"
  validation {
    condition     = length(var.authorized_ip_ranges) > 0
    error_message = "At least one authorized IP range must be provided."
  }
}

variable "kubernetes_version" {
  type        = string
  default     = null
  description = "Kubernetes version (null = latest)"
}

variable "system_node_vm_size" {
  type        = string
  default     = "standard_b2s_v2"
  description = "VM size for system node pool"
  validation {
    # Accept both Standard_* and standard_* formats, with optional _v2 suffix
    # Convert to lowercase for comparison to handle both cases
    condition     = can(regex("^standard_[a-z][0-9]+[a-z]*(_v[0-9]+)?$", lower(var.system_node_vm_size)))
    error_message = "VM size must be a valid Azure VM size (e.g., standard_b2s_v2, Standard_B2s)."
  }
}

variable "system_node_min" {
  type        = number
  description = "Minimum number of nodes in system pool"
  validation {
    condition     = var.system_node_min >= 1 && var.system_node_min <= 100
    error_message = "System node min must be between 1 and 100."
  }
}

variable "system_node_max" {
  type        = number
  description = "Maximum number of nodes in system pool"
  validation {
    condition     = var.system_node_max >= var.system_node_min && var.system_node_max <= 100
    error_message = "System node max must be >= min and <= 100."
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

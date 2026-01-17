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

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace for the service account"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.k8s_namespace)) && length(var.k8s_namespace) <= 63
    error_message = "K8s namespace must be a valid Kubernetes namespace name (lowercase alphanumeric with hyphens, max 63 chars)."
  }
}

variable "k8s_service_account_name" {
  type        = string
  description = "Kubernetes service account name"
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.k8s_service_account_name)) && length(var.k8s_service_account_name) <= 253
    error_message = "K8s service account name must be a valid Kubernetes name (lowercase alphanumeric with hyphens, max 253 chars)."
  }
}

# Service needs
variable "needs_keyvault" {
  type        = bool
  default     = false
  description = "Whether the service needs Key Vault access"
}

variable "needs_servicebus" {
  type        = bool
  default     = false
  description = "Whether the service needs Service Bus access"
}

variable "needs_storage" {
  type        = bool
  default     = false
  description = "Whether the service needs Storage Account access"
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

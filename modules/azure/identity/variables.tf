variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }

variable "tags" { type = map(string) }

# Workload Identity federation
variable "oidc_issuer_url" { type = string }
variable "k8s_namespace" { type = string }
variable "k8s_service_account_name" { type = string }

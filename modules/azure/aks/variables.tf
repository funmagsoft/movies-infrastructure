variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "dns_prefix" { type = string }

variable "subnet_id" { type = string }

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "system_node_min" {
  type    = number
  default = 1
}

variable "system_node_max" {
  type    = number
  default = 2
}

variable "authorized_ip_ranges" {
  type    = list(string)
  default = ["91.150.222.105/32"]
}

variable "tags" {
  type = map(string)
}

# Optional: enable Entra RBAC later
variable "enable_aad_rbac" {
  type    = bool
  default = false
}

variable "aad_admin_group_object_ids" {
  type    = list(string)
  default = []
}

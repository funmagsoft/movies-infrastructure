variable "org" {
  type    = string
  default = "fms"
}

variable "project" {
  type    = string
  default = "movies"
}

variable "project_short" {
  type    = string
  default = "mov"
}

variable "region" {
  type    = string
  default = "polandcentral"
}

variable "region_short" {
  type    = string
  default = "plc"
}

variable "instance" {
  type    = string
  default = "01"
}

# auto-injected by ./scripts/generate-backends.sh
variable "tfstate_resource_group_name" { type = string }
variable "tfstate_storage_account_name" { type = string }

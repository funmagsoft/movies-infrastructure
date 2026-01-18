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

variable "subscription_id" {
  type        = string
  default     = null
  description = "Azure subscription ID. If not provided, will be read from Azure CLI or ARM_SUBSCRIPTION_ID environment variable."
}

variable "tags" {
  type = map(string)
  default = {
    org         = "fms"
    project     = "movies"
    environment = "shared"
    region      = "polandcentral"
    managedBy   = "terraform"
    repo        = "movies-infrastructure"
    stack       = "bootstrap"
    owner       = "platform"
    costCenter  = "movies"
  }
}

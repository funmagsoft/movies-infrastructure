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

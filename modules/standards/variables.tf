variable "org" { type = string }
variable "project" { type = string }
variable "project_short" { type = string, default = "mov" }
variable "environment" { type = string }
variable "region" { type = string, default = "polandcentral" }
variable "region_short" { type = string, default = "plc" }
variable "instance" { type = string, default = "01" }
variable "stack" { type = string }

variable "owner" { type = string, default = "platform" }
variable "cost_center" { type = string, default = "movies" }

variable "extra_tags" {
  type    = map(string)
  default = {}
}

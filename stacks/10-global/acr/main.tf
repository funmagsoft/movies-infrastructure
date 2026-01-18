module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = "shared"
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "acr"
}

locals {
  rg_name  = "rg-${module.std.name_suffix}"  # rg-fms-movies-shared-plc-01
  acr_name = substr("acr${module.std.constrained_suffix}", 0, 50)
}

# Resource Group is created by bootstrap stack (stacks/00-bootstrap/backend-local)
# We reference it using data source instead of creating it
data "azurerm_resource_group" "global" {
  name = local.rg_name
}

module "acr" {
  source              = "../../../modules/azure/acr"
  name                = local.acr_name
  resource_group_name = data.azurerm_resource_group.global.name
  location            = data.azurerm_resource_group.global.location
  sku                 = "Basic"
  tags                = module.std.tags
}

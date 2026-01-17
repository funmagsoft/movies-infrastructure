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

resource "azurerm_resource_group" "global" {
  name     = local.rg_name
  location = var.region
  tags     = module.std.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

module "acr" {
  source              = "../../../modules/azure/acr"
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.global.name
  location            = azurerm_resource_group.global.location
  sku                 = "Basic"
  tags                = module.std.tags
}

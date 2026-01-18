module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = var.environment
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "core"
}

locals {
  rg_name   = "rg-${module.std.name_suffix}"
  vnet_name = "vnet-${module.std.name_suffix}"

  snet_aks = "snet-aks-${module.std.name_suffix}"
  snet_pe  = "snet-pe-${module.std.name_suffix}"

  # Reference to the correct resource group based on environment
  resource_group = var.environment == "prod" ? azurerm_resource_group.env[0] : azurerm_resource_group.env_nonprod[0]
}

# Resource group with prevent_destroy for production
resource "azurerm_resource_group" "env" {
  count    = var.environment == "prod" ? 1 : 0
  name     = local.rg_name
  location = var.region
  tags     = module.std.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

# Resource group without prevent_destroy for non-production environments
resource "azurerm_resource_group" "env_nonprod" {
  count    = var.environment != "prod" ? 1 : 0
  name     = local.rg_name
  location = var.region
  tags     = module.std.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

module "network" {
  source              = "../../../modules/azure/network"
  resource_group_name = local.resource_group.name
  location            = local.resource_group.location
  vnet_name           = local.vnet_name
  address_space       = var.address_space

  subnets = {
    (local.snet_aks) = { address_prefixes = var.subnet_prefixes.aks_nodes }
    (local.snet_pe)  = { address_prefixes = var.subnet_prefixes.private_endpoints }
  }

  tags = module.std.tags
}

module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = var.environment
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "observability"
}

locals {
  core_state_key = "${var.environment}/platform/core.tfstate"
}

data "terraform_remote_state" "core" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = "tfstate-${var.environment}"
    key                  = local.core_state_key
    use_azuread_auth     = true
  }
}

locals {
  rg_name = data.terraform_remote_state.core.outputs.resource_group_name
  law_name = "law-${module.std.name_suffix}"
}

module "law" {
  source              = "../../../modules/azure/observability"
  enabled             = var.enable_observability
  name                = local.law_name
  resource_group_name = local.rg_name
  location            = var.region
  tags                = module.std.tags
}

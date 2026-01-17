module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = var.environment
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "security"
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

# Optional: RG lock
resource "azurerm_management_lock" "rg_lock" {
  count      = var.enable_rg_lock ? 1 : 0
  name       = "lock-${var.environment}"
  scope      = data.terraform_remote_state.core.outputs.vnet_id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform"
}

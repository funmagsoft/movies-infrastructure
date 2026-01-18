module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = var.environment
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "data"
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

  kv_name = substr("kv${module.std.constrained_suffix}", 0, 24)
  sb_name = "sb-${module.std.name_suffix}"
  st_name = substr("st${module.std.constrained_suffix}app", 0, 24)
}

module "kv" {
  source                     = "../../../modules/azure/keyvault"
  enabled                    = var.enable_keyvault
  name                       = local.kv_name
  resource_group_name        = local.rg_name
  location                   = var.region
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  enable_purge_protection    = var.environment == "prod"
  enable_private_endpoint    = var.enable_private_endpoints
  private_endpoint_subnet_id = var.enable_private_endpoints ? data.terraform_remote_state.core.outputs.private_endpoints_subnet_id : ""
  # Enable public access for dev/stage when Private Endpoint is enabled (allows Azure Portal access)
  # For prod, keep default behavior (public access disabled when Private Endpoint is enabled)
  public_network_access_enabled = var.enable_private_endpoints && contains(["dev", "stage"], var.environment) ? true : null
  tags                          = module.std.tags
}

module "sb" {
  source              = "../../../modules/azure/servicebus"
  enabled             = var.enable_servicebus
  name                = local.sb_name
  resource_group_name = local.rg_name
  location            = var.region
  sku                 = "Basic"
  tags                = module.std.tags
}

module "st" {
  source              = "../../../modules/azure/storage"
  enabled             = var.enable_storage
  name                = local.st_name
  resource_group_name = local.rg_name
  location            = var.region
  tags                = module.std.tags
}

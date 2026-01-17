module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = var.environment
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "app-backend"
}

locals {
  aks_state_key  = "${var.environment}/platform/aks.tfstate"
  data_state_key = "${var.environment}/platform/data.tfstate"
}

data "terraform_remote_state" "aks" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = "tfstate-${var.environment}"
    key                  = local.aks_state_key
    use_azuread_auth     = true
  }
}

data "terraform_remote_state" "data" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = "tfstate-${var.environment}"
    key                  = local.data_state_key
    use_azuread_auth     = true
  }
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

  uami_name = "uami-${module.std.name_suffix}-backend"
}

module "identity" {
  source              = "../../../modules/azure/identity"
  name                = local.uami_name
  resource_group_name = local.rg_name
  location            = var.region
  tags                = module.std.tags

  oidc_issuer_url           = data.terraform_remote_state.aks.outputs.oidc_issuer_url
  k8s_namespace             = var.k8s_namespace
  k8s_service_account_name  = var.k8s_service_account_name
}

# Optional role assignments (only if the platform resource exists AND the service declares it needs it)
resource "azurerm_role_assignment" "kv_secrets_user" {
  count                = (var.needs_keyvault && data.terraform_remote_state.data.outputs.keyvault_id != null) ? 1 : 0
  scope                = data.terraform_remote_state.data.outputs.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.identity.principal_id
}

resource "azurerm_role_assignment" "sb_data_sender" {
  count                = (var.needs_servicebus && data.terraform_remote_state.data.outputs.servicebus_id != null) ? 1 : 0
  scope                = data.terraform_remote_state.data.outputs.servicebus_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = module.identity.principal_id
}

resource "azurerm_role_assignment" "st_blob_contrib" {
  count                = (var.needs_storage && data.terraform_remote_state.data.outputs.storage_id != null) ? 1 : 0
  scope                = data.terraform_remote_state.data.outputs.storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.identity.principal_id
}

module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = var.environment
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "aks"
}

# Read core stack state in the same env container
# Key is derived by scripts/tf.sh, but remote_state needs a fixed key.
# We compute it explicitly to match that convention.
locals {
  core_state_key = "${var.environment}/platform/core.tfstate"
  acr_state_key  = "global/acr.tfstate"
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

# Read global ACR state
data "terraform_remote_state" "acr" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = "tfstate-global"
    key                  = local.acr_state_key
    use_azuread_auth     = true
  }
}

locals {
  rg_name = data.terraform_remote_state.core.outputs.resource_group_name

  pip_name = "pip-ingress-${module.std.name_suffix}"
}

resource "azurerm_public_ip" "ingress" {
  name                = local.pip_name
  resource_group_name = local.rg_name
  location            = var.region

  allocation_method = "Static"
  sku               = "Standard"

  tags = module.std.tags
}

module "aks" {
  source              = "../../../modules/azure/aks"
  name                = "aks-${module.std.name_suffix}"
  resource_group_name = local.rg_name
  location            = var.region
  dns_prefix          = "aks-${var.environment}-${var.region_short}"

  subnet_id = data.terraform_remote_state.core.outputs.aks_subnet_id

  kubernetes_version = var.kubernetes_version

  system_node_vm_size = var.system_node_vm_size
  system_node_min     = var.system_node_min
  system_node_max     = var.system_node_max

  authorized_ip_ranges = var.authorized_ip_ranges

  tags = module.std.tags
}

# Allow AKS managed identity to manage the pre-created Public IP
resource "azurerm_role_assignment" "aks_pip_network_contrib" {
  scope                = azurerm_public_ip.ingress.id
  role_definition_name = "Network Contributor"
  principal_id         = module.aks.cluster_principal_id
}

# Lookup shared ACR from global stack and grant AcrPull to kubelet identity
# Use remote state outputs instead of variables for better dependency management

data "azurerm_container_registry" "acr" {
  name                = data.terraform_remote_state.acr.outputs.acr_name
  resource_group_name = data.terraform_remote_state.acr.outputs.resource_group_name
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks.kubelet_object_id
}

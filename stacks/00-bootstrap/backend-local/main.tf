module "std" {
  source        = "../../../modules/standards"
  org           = var.org
  project       = var.project
  project_short = var.project_short
  environment   = "shared"
  region        = var.region
  region_short  = var.region_short
  instance      = var.instance
  stack         = "bootstrap"
}

locals {
  rg_name = "rg-${module.std.name_suffix}"  # rg-fms-movies-shared-plc-01

  # Constrained name for tfstate storage account
  # st + constrained_suffix (<= 24)
  sa_name = substr("st${module.std.constrained_suffix}tf", 0, 24)
}

resource "azurerm_resource_group" "tfstate" {
  name     = local.rg_name
  location = var.region
  tags     = module.std.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                     = local.sa_name
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  allow_blob_public_access  = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }

  tags = module.std.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

resource "azurerm_storage_container" "global" {
  name                  = "tfstate-global"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "dev" {
  name                  = "tfstate-dev"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "stage" {
  name                  = "tfstate-stage"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "prod" {
  name                  = "tfstate-prod"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

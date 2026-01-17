resource "azurerm_storage_account" "this" {
  count               = var.enabled ? 1 : 0
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type

  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
  allow_blob_public_access  = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "app" {
  count                 = var.enabled ? 1 : 0
  name                  = "app"
  storage_account_name  = azurerm_storage_account.this[0].name
  container_access_type = "private"
}

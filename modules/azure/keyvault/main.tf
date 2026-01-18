resource "azurerm_key_vault" "this" {
  count               = var.enabled ? 1 : 0
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  tenant_id = var.tenant_id
  sku_name  = var.sku_name

  soft_delete_retention_days = 7
  purge_protection_enabled   = var.enable_purge_protection

  # If public_network_access_enabled is explicitly set, use it; otherwise default to false when private endpoint is enabled
  public_network_access_enabled = var.public_network_access_enabled != null ? var.public_network_access_enabled : !var.enable_private_endpoint

  tags = var.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, purge_protection_enabled]
  }
}

resource "azurerm_private_endpoint" "this" {
  count               = var.enabled && var.enable_private_endpoint ? 1 : 0
  name                = "${var.name}-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name}-psc"
    private_connection_resource_id = azurerm_key_vault.this[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = var.tags
}

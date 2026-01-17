resource "azurerm_servicebus_namespace" "this" {
  count               = var.enabled ? 1 : 0
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku = var.sku
  tags = var.tags
}

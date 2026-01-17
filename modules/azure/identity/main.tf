resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  name                = "fic-${var.k8s_namespace}-${var.k8s_service_account_name}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id

  issuer   = var.oidc_issuer_url
  subject  = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
  audience = ["api://AzureADTokenExchange"]
}

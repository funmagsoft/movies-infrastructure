output "id" {
  value = try(azurerm_key_vault.this[0].id, null)
}
output "name" {
  value = try(azurerm_key_vault.this[0].name, null)
}

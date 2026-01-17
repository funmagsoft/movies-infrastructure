output "id" { value = try(azurerm_servicebus_namespace.this[0].id, null) }
output "name" { value = try(azurerm_servicebus_namespace.this[0].name, null) }

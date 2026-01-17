output "id" { value = try(azurerm_log_analytics_workspace.this[0].id, null) }
output "name" { value = try(azurerm_log_analytics_workspace.this[0].name, null) }

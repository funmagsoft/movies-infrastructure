output "tfstate_resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}

output "tfstate_storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "containers" {
  value = {
    global = azurerm_storage_container.global.name
    dev    = azurerm_storage_container.dev.name
    stage  = azurerm_storage_container.stage.name
    prod   = azurerm_storage_container.prod.name
  }
}

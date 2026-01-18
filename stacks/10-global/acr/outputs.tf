output "acr_id" { value = module.acr.id }
output "acr_name" { value = module.acr.name }
output "acr_login_server" { value = module.acr.login_server }
output "resource_group_name" { value = data.azurerm_resource_group.global.name }

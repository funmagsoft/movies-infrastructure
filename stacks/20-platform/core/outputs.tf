output "resource_group_name" {
  value = azurerm_resource_group.env.name
}

output "location" {
  value = azurerm_resource_group.env.location
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "subnet_ids" {
  value = module.network.subnet_ids
}

output "aks_subnet_id" {
  value = module.network.subnet_ids["${local.snet_aks}"]
}

output "private_endpoints_subnet_id" {
  value = module.network.subnet_ids["${local.snet_pe}"]
}

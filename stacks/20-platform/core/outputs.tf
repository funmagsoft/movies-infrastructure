output "resource_group_name" {
  value = local.resource_group.name
}

output "location" {
  value = local.resource_group.location
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

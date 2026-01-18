output "aks_name" { value = module.aks.name }
output "aks_id" { value = module.aks.id }
output "oidc_issuer_url" { value = module.aks.oidc_issuer_url }
output "node_resource_group" { value = module.aks.node_resource_group }
output "api_server_url" {
  description = "API server URL (FQDN)"
  value       = module.aks.api_server_url
}
output "api_server_fqdn" {
  description = "API server FQDN (without https://)"
  value       = module.aks.fqdn
}

output "ingress_public_ip_name" { value = azurerm_public_ip.ingress.name }
output "ingress_public_ip_resource_group" { value = azurerm_public_ip.ingress.resource_group_name }
output "ingress_public_ip" { value = azurerm_public_ip.ingress.ip_address }

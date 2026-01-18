output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "resource_group_name" { value = azurerm_kubernetes_cluster.this.resource_group_name }
output "node_resource_group" { value = azurerm_kubernetes_cluster.this.node_resource_group }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "kubelet_object_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id }
output "cluster_principal_id" { value = azurerm_kubernetes_cluster.this.identity[0].principal_id }
output "fqdn" { value = azurerm_kubernetes_cluster.this.fqdn }
output "api_server_url" {
  description = "API server URL (FQDN)"
  value       = "https://${azurerm_kubernetes_cluster.this.fqdn}"
}

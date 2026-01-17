# AKS Module

Moduł do tworzenia Azure Kubernetes Service (AKS) z konfiguracją dla Workload Identity i publicznym API server z allow-list.

## Funkcje

- AKS z SystemAssigned identity
- OIDC issuer enabled (dla Workload Identity)
- Workload Identity enabled
- Publiczny API server z authorized IP ranges
- Auto-scaling node pool
- Azure CNI z overlay mode
- Opcjonalne Entra ID RBAC

## Użycie

```hcl
module "aks" {
  source = "../../modules/azure/aks"
  
  name                = "aks-fms-movies-dev-plc-01"
  resource_group_name = azurerm_resource_group.env.name
  location            = "polandcentral"
  dns_prefix          = "aks-dev-plc"
  subnet_id           = azurerm_subnet.aks.id
  
  kubernetes_version  = "1.28"
  system_node_vm_size  = "Standard_B2s"
  system_node_min      = 1
  system_node_max      = 3
  
  authorized_ip_ranges = ["91.150.222.105/32"]
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `name` | string | Tak | - | Nazwa klastra AKS |
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `dns_prefix` | string | Tak | - | DNS prefix dla API server |
| `subnet_id` | string | Tak | - | ID subnetu dla node pool |
| `kubernetes_version` | string | Nie | `null` | Wersja Kubernetes (null = latest) |
| `system_node_vm_size` | string | Nie | `"Standard_B2s"` | Rozmiar VM dla node pool |
| `system_node_min` | number | Nie | `1` | Minimalna liczba node'ów |
| `system_node_max` | number | Nie | `2` | Maksymalna liczba node'ów |
| `authorized_ip_ranges` | list(string) | Nie | `["91.150.222.105/32"]` | Dozwolone IP dla API server |
| `enable_aad_rbac` | bool | Nie | `false` | Włącz Entra ID RBAC |
| `aad_admin_group_object_ids` | list(string) | Nie | `[]` | Object IDs grup adminów |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu AKS |
| `name` | Nazwa klastra |
| `resource_group_name` | Nazwa resource group |
| `node_resource_group` | Nazwa resource group dla node'ów |
| `oidc_issuer_url` | URL OIDC issuer (dla Workload Identity) |
| `kubelet_object_id` | Object ID kubelet identity |
| `cluster_principal_id` | Principal ID system-assigned identity |

## Uwagi

- Node pool używa auto-scaling
- Domyślny rozmiar dysku OS: 30GB
- Network plugin: Azure CNI z overlay mode
- Load balancer: Standard SKU

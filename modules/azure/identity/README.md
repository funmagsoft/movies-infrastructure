# Identity Module

Moduł do tworzenia User Assigned Managed Identity z Federated Identity Credential dla Workload Identity w Kubernetes.

## Funkcje

- User Assigned Managed Identity
- Federated Identity Credential dla Kubernetes Service Account
- Integracja z AKS OIDC issuer

## Użycie

```hcl
module "identity" {
  source = "../../modules/azure/identity"
  
  name                = "uami-fms-movies-dev-plc-01-backend"
  resource_group_name = azurerm_resource_group.env.name
  location            = "polandcentral"
  
  oidc_issuer_url          = data.terraform_remote_state.aks.outputs.oidc_issuer_url
  k8s_namespace            = "default"
  k8s_service_account_name = "backend-sa"
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `name` | string | Tak | - | Nazwa User Assigned Identity |
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `oidc_issuer_url` | string | Tak | - | URL OIDC issuer z AKS |
| `k8s_namespace` | string | Tak | - | Kubernetes namespace |
| `k8s_service_account_name` | string | Tak | - | Kubernetes service account name |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu User Assigned Identity |
| `name` | Nazwa identity |
| `principal_id` | Principal ID (używany do role assignments) |
| `client_id` | Client ID (używany w aplikacjach) |

## Uwagi

- Federated Identity Credential łączy Azure Identity z Kubernetes Service Account
- Subject format: `system:serviceaccount:<namespace>:<service-account-name>`
- Po utworzeniu identity, przypisz role RBAC do zasobów Azure (np. Key Vault Secrets User)

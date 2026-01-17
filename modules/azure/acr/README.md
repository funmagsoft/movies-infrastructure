# ACR Module

Moduł do tworzenia Azure Container Registry.

## Funkcje

- Azure Container Registry
- Konfigurowalny SKU (Basic, Standard, Premium)
- Automatyczne tagowanie

## Użycie

```hcl
module "acr" {
  source = "../../modules/azure/acr"
  
  name                = "acrfmsmoviessharedplc01"
  resource_group_name = azurerm_resource_group.global.name
  location            = "polandcentral"
  sku                 = "Basic"
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `name` | string | Tak | - | Nazwa ACR (lowercase, alphanumeric, max 50 znaków) |
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `sku` | string | Nie | `"Basic"` | SKU (Basic, Standard, Premium) |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu ACR |
| `name` | Nazwa ACR |
| `login_server` | Login server URL (np. acrname.azurecr.io) |

## Uwagi

- Nazwa ACR musi być unikalna globalnie (max 50 znaków, lowercase alphanumeric)
- Basic SKU: 10GB storage, 1 webhook
- Standard SKU: 100GB storage, 2 webhooks
- Premium SKU: 500GB storage, 10 webhooks, geo-replication

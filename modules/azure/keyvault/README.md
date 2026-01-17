# Key Vault Module

Moduł do tworzenia Azure Key Vault z opcjonalnym purge protection.

## Funkcje

- Key Vault z soft delete (7 dni retention)
- Opcjonalne purge protection (zalecane dla prod)
- Standard lub Premium SKU
- Automatyczne tagowanie

## Użycie

```hcl
module "keyvault" {
  source = "../../modules/azure/keyvault"
  
  enabled                = true
  name                   = "kv-fms-movies-dev-plc-01"
  resource_group_name    = azurerm_resource_group.env.name
  location               = "polandcentral"
  tenant_id              = data.azurerm_client_config.current.tenant_id
  enable_purge_protection = var.environment == "prod"
  sku_name               = "standard"
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `enabled` | bool | Nie | `false` | Czy utworzyć Key Vault |
| `name` | string | Tak | - | Nazwa Key Vault (max 24 znaki) |
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `tenant_id` | string | Tak | - | Azure tenant ID |
| `sku_name` | string | Nie | `"standard"` | SKU (standard lub premium) |
| `enable_purge_protection` | bool | Nie | `false` | Włącz purge protection |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu Key Vault |
| `name` | Nazwa Key Vault |
| `uri` | URI Key Vault |

## Uwagi

- Soft delete retention: 7 dni
- Purge protection nie może być wyłączone po włączeniu (szczególnie w prod)
- Nazwa Key Vault musi być unikalna globalnie (max 24 znaki)
- Dla prod zalecane jest włączenie purge protection

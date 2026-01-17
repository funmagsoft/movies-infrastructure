# Storage Account Module

Moduł do tworzenia Azure Storage Account z kontenerem dla aplikacji.

## Funkcje

- Storage Account z hardening (HTTPS only, TLS 1.2)
- Blob versioning enabled
- Soft delete (7 dni)
- Private container "app"
- Opcjonalne tworzenie (enabled flag)

## Użycie

```hcl
module "storage" {
  source = "../../modules/azure/storage"
  
  enabled                = true
  name                   = "stfmsmoviesdevplc01app"
  resource_group_name    = azurerm_resource_group.env.name
  location               = "polandcentral"
  account_tier           = "Standard"
  account_replication_type = "LRS"
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `enabled` | bool | Nie | `false` | Czy utworzyć Storage Account |
| `name` | string | Tak | - | Nazwa Storage Account (lowercase, alphanumeric, max 24 znaki) |
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `account_tier` | string | Nie | `"Standard"` | Tier (Standard lub Premium) |
| `account_replication_type` | string | Nie | `"LRS"` | Replication type (LRS, GRS, etc.) |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu Storage Account |
| `name` | Nazwa Storage Account |
| `primary_blob_endpoint` | Primary blob endpoint |

## Uwagi

- HTTPS only: enabled
- TLS minimum version: 1.2
- Blob public access: disabled
- Blob versioning: enabled
- Soft delete retention: 7 dni
- Kontener "app" jest tworzony automatycznie (private access)

# Service Bus Module

Moduł do tworzenia Azure Service Bus Namespace.

## Funkcje

- Service Bus Namespace
- Konfigurowalny SKU (Basic, Standard, Premium)
- Opcjonalne tworzenie (enabled flag)
- Automatyczne tagowanie

## Użycie

```hcl
module "servicebus" {
  source = "../../modules/azure/servicebus"
  
  enabled             = true
  name                = "sb-fms-movies-dev-plc-01"
  resource_group_name = azurerm_resource_group.env.name
  location            = "polandcentral"
  sku                 = "Basic"
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `enabled` | bool | Nie | `false` | Czy utworzyć Service Bus |
| `name` | string | Tak | - | Nazwa Service Bus Namespace |
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `sku` | string | Nie | `"Basic"` | SKU (Basic, Standard, Premium) |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu Service Bus |
| `name` | Nazwa Service Bus Namespace |
| `default_primary_connection_string` | Primary connection string |

## Uwagi

- Basic SKU: podstawowe funkcje, brak topics
- Standard SKU: topics, sessions, duplicate detection
- Premium SKU: dedykowane zasoby, lepsza wydajność

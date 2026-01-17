# Network Module

Moduł do tworzenia Virtual Network i subnetów w Azure.

## Funkcje

- Virtual Network z konfigurowalnym address space
- Wielokrotne subnety
- Automatyczne tagowanie

## Użycie

```hcl
module "network" {
  source = "../../modules/azure/network"
  
  resource_group_name = azurerm_resource_group.env.name
  location            = "polandcentral"
  vnet_name           = "vnet-fms-movies-dev-plc-01"
  address_space       = ["10.60.0.0/16"]
  
  subnets = {
    "snet-aks" = {
      address_prefixes = ["10.60.0.0/20"]
    }
    "snet-pe" = {
      address_prefixes = ["10.60.20.0/24"]
    }
  }
  
  tags = local.tags
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `resource_group_name` | string | Tak | - | Nazwa resource group |
| `location` | string | Tak | - | Azure region |
| `vnet_name` | string | Tak | - | Nazwa Virtual Network |
| `address_space` | list(string) | Tak | - | CIDR blocks dla VNet |
| `subnets` | map(object) | Tak | - | Mapowanie nazw subnetów do address_prefixes |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `vnet_id` | ID Virtual Network |
| `vnet_name` | Nazwa Virtual Network |
| `subnet_ids` | Mapowanie nazw subnetów do ID |

## Uwagi

- Subnety są tworzone dynamicznie na podstawie mapy `subnets`
- Każdy subnet musi mieć unikalny address prefix
- Address prefixes muszą być w zakresie address_space VNet

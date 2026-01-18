# Key Vault Module

Moduł do tworzenia Azure Key Vault z opcjonalnym purge protection i Private Endpoint.

## Funkcje

- Key Vault z soft delete (7 dni retention)
- Opcjonalne purge protection (zalecane dla prod)
- Opcjonalny Private Endpoint dla bezpiecznego dostępu
- Elastyczna kontrola dostępu publicznego i prywatnego
- Standard lub Premium SKU
- Automatyczne tagowanie

## Użycie

### Podstawowe użycie (publiczny dostęp)

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

### Z Private Endpoint (tylko dostęp prywatny)

```hcl
module "keyvault" {
  source = "../../modules/azure/keyvault"
  
  enabled                  = true
  name                     = "kv-fms-movies-prod-plc-01"
  resource_group_name      = azurerm_resource_group.env.name
  location                 = "polandcentral"
  tenant_id                = data.azurerm_client_config.current.tenant_id
  enable_purge_protection  = true
  enable_private_endpoint   = true
  private_endpoint_subnet_id = data.terraform_remote_state.core.outputs.private_endpoints_subnet_id
  sku_name                  = "standard"
  
  tags = local.tags
}
```

### Z Private Endpoint i publicznym dostępem (hybrydowy)

```hcl
module "keyvault" {
  source = "../../modules/azure/keyvault"
  
  enabled                  = true
  name                     = "kv-fms-movies-dev-plc-01"
  resource_group_name      = azurerm_resource_group.env.name
  location                 = "polandcentral"
  tenant_id                = data.azurerm_client_config.current.tenant_id
  enable_private_endpoint   = true
  private_endpoint_subnet_id = data.terraform_remote_state.core.outputs.private_endpoints_subnet_id
  public_network_access_enabled = true  # Pozwala na dostęp z Azure Portal
  sku_name                  = "standard"
  
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
| `enable_private_endpoint` | bool | Nie | `false` | Włącz Private Endpoint |
| `private_endpoint_subnet_id` | string | Nie | `""` | Subnet ID dla Private Endpoint (wymagane jeśli `enable_private_endpoint = true`) |
| `public_network_access_enabled` | bool | Nie | `null` | Włącz dostęp publiczny. Jeśli `null`, automatycznie `false` gdy Private Endpoint włączony, `true` w przeciwnym razie. Ustaw jawnie aby pozwolić na oba typy dostępu. |
| `tags` | map(string) | Tak | - | Tagi do zastosowania |

## Outputy

| Nazwa | Opis |
|-------|------|
| `id` | ID zasobu Key Vault |
| `name` | Nazwa Key Vault |
| `uri` | URI Key Vault |

## Konfiguracja dostępu sieciowego

### Scenariusz 1: Tylko dostęp publiczny (domyślny)
- `enable_private_endpoint = false`
- `public_network_access_enabled = null` (domyślnie `true`)
- **Dostęp**: Z Azure Portal, z internetu (z odpowiednimi uprawnieniami)

### Scenariusz 2: Tylko dostęp prywatny (produkcja)
- `enable_private_endpoint = true`
- `public_network_access_enabled = null` (domyślnie `false`)
- **Dostęp**: Tylko z sieci prywatnej (VPN, ExpressRoute, maszyny wirtualne w VNet)

### Scenariusz 3: Dostęp hybrydowy (dev/test)
- `enable_private_endpoint = true`
- `public_network_access_enabled = true`
- **Dostęp**: Z sieci prywatnej (Private Endpoint) oraz z internetu (Azure Portal, API)
- **Uwaga**: Można dodatkowo ograniczyć dostęp publiczny przez Key Vault firewall/IP restrictions

## Uwagi

- Soft delete retention: 7 dni
- Purge protection nie może być wyłączone po włączeniu (szczególnie w prod)
- Nazwa Key Vault musi być unikalna globalnie (max 24 znaki)
- Dla prod zalecane jest włączenie purge protection i Private Endpoint
- Gdy `public_network_access_enabled = false` i Private Endpoint włączony, dostęp z Azure Portal wymaga połączenia z siecią prywatną (VPN/ExpressRoute) lub użycia maszyny wirtualnej w VNet

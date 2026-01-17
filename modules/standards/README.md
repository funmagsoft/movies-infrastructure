# Standards Module

Moduł centralizujący konwencje nazewnictwa i tagowania dla wszystkich zasobów Azure.

## Funkcje

- Centralizacja naming convention
- Automatyczne generowanie tagów
- Obsługa constrained names (dla zasobów z ograniczeniami nazw)
- Mapowanie environment na krótkie kody

## Użycie

```hcl
module "std" {
  source = "../../modules/standards"
  
  org           = "fms"
  project       = "movies"
  project_short = "mov"
  environment   = "dev"
  region        = "polandcentral"
  region_short  = "plc"
  instance      = "01"
  stack         = "core"
  
  owner       = "platform"
  cost_center = "movies"
}
```

## Zmienne

| Nazwa | Typ | Wymagane | Domyślna | Opis |
|-------|-----|----------|----------|------|
| `org` | string | Tak | - | Organizacja |
| `project` | string | Tak | - | Nazwa projektu |
| `project_short` | string | Tak | - | Krótka nazwa projektu (dla constrained names) |
| `environment` | string | Tak | - | Środowisko (dev, stage, prod, shared, global) |
| `region` | string | Tak | - | Azure region (pełna nazwa) |
| `region_short` | string | Tak | - | Krótki kod regionu |
| `instance` | string | Tak | - | Numer instancji (01, 02, ...) |
| `stack` | string | Tak | - | Nazwa stacka |
| `owner` | string | Nie | `"platform"` | Właściciel zasobów |
| `cost_center` | string | Nie | `"movies"` | Cost center |
| `extra_tags` | map(string) | Nie | `{}` | Dodatkowe tagi |

## Outputy

| Nazwa | Opis |
|-------|------|
| `name_suffix` | Suffix dla friendly names (np. `fms-movies-dev-plc-01`) |
| `constrained_suffix` | Suffix dla constrained names (lowercase, bez myślników) |
| `tags` | Mapowanie tagów do zastosowania |
| `env_short` | Krótki kod środowiska (d, s, p, x) |
| `sub_hash` | Hash subskrypcji (dla unikalności) |

## Przykłady

### Friendly name
```
rg-${module.std.name_suffix}
→ rg-fms-movies-dev-plc-01
```

### Constrained name
```
acr${module.std.constrained_suffix}
→ acrfmsmovdplc<hash>01
```

## Uwagi

- `name_suffix` używa myślników (dla czytelności)
- `constrained_suffix` używa tylko lowercase alphanumeric (dla zasobów z ograniczeniami)
- `sub_hash` zapewnia unikalność globalną dla constrained names

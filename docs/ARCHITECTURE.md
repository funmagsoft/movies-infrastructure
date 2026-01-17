# Architektura infrastruktury

## Przegląd

Repozytorium infrastruktury dla systemu **movies** (organizacja **fms**) wdrażanego na Azure w regionie **polandcentral**.

- **IaC:** Terraform
- **Środowiska:** dev / stage / prod
- **AKS:** publiczny endpoint API z allow-list IP: `91.150.222.105/32`
- **ACR:** jeden współdzielony dla wszystkich środowisk
- **GitOps:** Argo CD (instalacja inicjalna ręczna), manifesty w osobnym repo: `funmagsoft/movies-gitops`

> W tym repo nie wykonujemy wdrożeń aplikacji do klastra przez CI (kubectl/helm). CI (GitHub Actions) zarządza zasobami Azure przez ARM. Zmiany w Kubernetes są dostarczane przez Argo CD.

## Konwencje

### Naming

Standard nazw (friendly):

`<rtype>-<org>-<project>-<env>-<region>-<nn>`

- `org = fms`
- `project = movies`
- `env = dev | stage | prod`
- `region = plc` (polandcentral)
- `nn = 01, 02...`

Przykłady:

- `rg-fms-movies-dev-plc-01`
- `vnet-fms-movies-prod-plc-01`
- `aks-fms-movies-stage-plc-01`

**Zasoby z ograniczeniami nazw** (ACR, Storage Account) używają wariantu „constrained” (lowercase + cyfry, bez myślników, z deterministycznym sufiksem). Zawsze utrzymujemy mapowalność do `org/project/env/region`.

### Tagowanie

Wymuszane tagi na zasobach Azure wspierających tagi:

- `org = fms`
- `project = movies`
- `environment = dev|stage|prod`
- `region = polandcentral`
- `managedBy = terraform`
- `repo = movies-infrastructure`
- `stack = <stack-name>`
- `owner = platform`
- `costCenter = movies`

> Entra ID (App registrations / Service principals) nie wspiera tagów – stosujemy konsekwentny naming.

## Struktura repozytorium

- `modules/` – moduły reużywalne
- `stacks/` – **root modules** (to te katalogi są wdrażane poleceniami Terraform)
- `env/` – konfiguracja środowisk (tfvars + backend.hcl)
- `scripts/` – wrappery ułatwiające init/plan/apply i generowanie backendów
- `docs/` – dokumentacja
- `tests/` – testy modułów i integracyjne

### Root modules (stacks)

- `stacks/00-bootstrap/backend-local` – bootstrap backendu stanu Terraform (Storage + kontenery)
- `stacks/10-global/acr` – ACR współdzielony
- `stacks/20-platform/core` – RG, VNET, subnety
- `stacks/20-platform/aks` – AKS publiczny z allow-list + Workload Identity + statyczny Public IP dla ingress
- `stacks/20-platform/data` – KV/SB/Storage (opcjonalne, sterowane flagami)
- `stacks/20-platform/observability` – Log Analytics / monitoring (opcjonalne)
- `stacks/20-platform/security` – security policies i locks
- `stacks/30-apps/frontend` – tożsamość + RBAC dla serwisu frontend
- `stacks/30-apps/backend` – tożsamość + RBAC dla serwisu backend

### Konfiguracja środowisk (env)

- `env/dev/platform/*.tfvars`
- `env/stage/platform/*.tfvars`
- `env/prod/platform/*.tfvars`

oraz backend:

- `env/dev/backend.hcl`
- `env/stage/backend.hcl`
- `env/prod/backend.hcl`
- `env/global/backend.hcl`

## Model tożsamości (GitHub Actions + OIDC)

### Założenia

Używamy OIDC z GitHub Actions (bez sekretów klienta). Rekomendowany podział tożsamości:

- `sp-tf-global-fms-movies` – stacki globalne (np. ACR)
- `sp-tf-dev-fms-movies` – stacki dev
- `sp-tf-stage-fms-movies` – stacki stage
- `sp-tf-prod-fms-movies` – stacki prod

W backendzie tfstate utrzymujemy **osobne kontenery**:

- `tfstate-global`
- `tfstate-dev`
- `tfstate-stage`
- `tfstate-prod`

Cel: separacja blast radius i ograniczenie dostępu do stanu prod.

### Uprawnienia (propozycja startowa)

Na start akceptujemy, że SP środowiskowe mają możliwość tworzenia `roleAssignments` (dla UAMI i dostępu do usług), więc przyznajemy:

- Na RG danego env: `Owner` *(lub alternatywnie: `Contributor` + `User Access Administrator`)*
- Na kontenerze tfstate: `Storage Blob Data Contributor`
- Na RG backendu (tfstate): `Reader`

Dodatkowo:

- SP dla env powinny mieć **read-only** do `tfstate-global` (aby pobrać outputy ACR przez `terraform_remote_state`).

> Docelowo można przejść do bardziej restrykcyjnego modelu z custom role lub osobną tożsamością do `security` stacka.

### Federated Identity Credentials (FIC)

Dla każdego SP dodaj FIC ograniczony do:

- repo: `funmagsoft/movies-infrastructure`
- GitHub Environment: `dev`, `stage`, `prod`, `global`

Typowy `subject` dla environment:

`repo:funmagsoft/movies-infrastructure:environment:<ENV>`

**Rekomendacja bezpieczeństwa**:

- W GitHub ustaw Environments (dev/stage/prod) i włącz approvals dla prod.
- Włącz branch protections (np. tylko `main`).

## Diagram zależności

```text
┌─────────────────┐
│   Bootstrap     │ (lokalny stan)
│  backend-local  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Global ACR     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Platform Core  │ (RG, VNET, subnety)
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│  AKS   │ │  Data  │ (KV, SB, Storage)
└───┬────┘ └───┬────┘
    │          │
    └────┬─────┘
         ▼
┌─────────────────┐
│  Apps (Identity)│ (frontend, backend)
└─────────────────┘
```

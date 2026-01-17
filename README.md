# Movies Infrastructure

Repozytorium infrastruktury dla systemu **movies** (organizacja **fms**) wdrażanego na Azure w regionie **polandcentral**.

- **IaC:** Terraform
- **Środowiska:** dev / stage / prod
- **AKS:** publiczny endpoint API z allow-list IP: `91.150.222.105/32`
- **ACR:** jeden współdzielony dla wszystkich środowisk
- **GitOps:** Argo CD (instalacja inicjalna ręczna), manifesty w osobnym repo: `funmagsoft/movies-gitops`

> W tym repo nie wykonujemy wdrożeń aplikacji do klastra przez CI (kubectl/helm). CI (GitHub Actions) zarządza zasobami Azure przez ARM. Zmiany w Kubernetes są dostarczane przez Argo CD.

## Quick Start

### Wymagania

- Terraform >= 1.6.0
- Azure CLI
- Git

### Pierwsze kroki

1. **Bootstrap backend:**

   ```bash
   cd stacks/00-bootstrap/backend-local
   terraform init
   terraform apply
   cd ../../..
   ./scripts/generate-backends.sh
   ```

2. **Wdróż globalny ACR:**

   ```bash
   ./scripts/tf.sh global 10-global/acr apply
   ```

3. **Wdróż platformę (per środowisko):**

   ```bash
   ./scripts/tf.sh dev 20-platform/core apply
   ./scripts/tf.sh dev 20-platform/aks apply
   ```

Więcej szczegółów w [dokumentacji](docs/).

## Dokumentacja

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Architektura, konwencje, model tożsamości
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Procedury wdrożenia i bootstrap
- **[OPERATIONS.md](docs/OPERATIONS.md)** - Operacje day-2, GitOps, monitoring
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Rozwiązywanie problemów

## Struktura repozytorium

- `modules/` - moduły reużywalne Terraform
- `stacks/` - root modules (wdrażane stacki)
- `env/` - konfiguracja środowisk (tfvars + backend.hcl)
- `scripts/` - skrypty pomocnicze
- `docs/` - dokumentacja
- `tests/` - testy modułów i integracyjne

## Konwencje

### 1.1 Naming

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

### 1.2 Tagowanie

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

## 2. Struktura repo

- `modules/` – moduły reużywalne
- `stacks/` – **root modules** (to te katalogi są wdrażane poleceniami Terraform)
- `env/` – konfiguracja środowisk (tfvars + backend.hcl)
- `scripts/` – wrappery ułatwiające init/plan/apply i generowanie backendów

### 2.1 Root modules (stacks)

- `stacks/00-bootstrap/backend-local` – bootstrap backendu stanu Terraform (Storage + kontenery)
- `stacks/10-global/acr` – ACR współdzielony
- `stacks/20-platform/core` – RG, VNET, subnety
- `stacks/20-platform/aks` – AKS publiczny z allow-list + Workload Identity + statyczny Public IP dla ingress
- `stacks/20-platform/data` – KV/SB/Storage (opcjonalne, sterowane flagami)
- `stacks/20-platform/observability` – Log Analytics / monitoring (opcjonalne)
- `stacks/30-apps/frontend` – tożsamość + RBAC dla serwisu frontend
- `stacks/30-apps/backend` – tożsamość + RBAC dla serwisu backend

### 2.2 Konfiguracja środowisk (env)

- `env/dev/platform/*.tfvars`
- `env/stage/platform/*.tfvars`
- `env/prod/platform/*.tfvars`

oraz backend:

- `env/dev/backend.hcl`
- `env/stage/backend.hcl`
- `env/prod/backend.hcl`
- (opcjonalnie) `env/global/backend.hcl`

## 3. Wymagania wstępne

### 3.1 Narzędzia

- Terraform (zgodny z wersją określoną w `standards/versions.tf`)
- Azure CLI (`az`)
- Git
- (opcjonalnie) `jq`

### 3.2 Dostęp i uprawnienia

Zakładamy **jedną subskrypcję** dla wszystkich env.

Minimalnie potrzebujesz uprawnień, aby:

- utworzyć Storage Account i kontenery na tfstate,
- utworzyć App registrations / Service principals oraz skonfigurować OIDC (federated credentials),
- nadać role RBAC (w tym role assignments dla managed identities).

## 4. Model tożsamości (GitHub Actions + OIDC)

### 4.1 Założenia

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

### 4.2 Uprawnienia (propozycja startowa)

Na start akceptujemy, że SP środowiskowe mają możliwość tworzenia `roleAssignments` (dla UAMI i dostępu do usług), więc przyznajemy:

- Na RG danego env: `Owner` *(lub alternatywnie: `Contributor` + `User Access Administrator`)*
- Na kontenerze tfstate: `Storage Blob Data Contributor`
- Na RG backendu (tfstate): `Reader`

Dodatkowo:

- SP dla env powinny mieć **read-only** do `tfstate-global` (aby pobrać outputy ACR przez `terraform_remote_state`).

> Docelowo można przejść do bardziej restrykcyjnego modelu z custom role lub osobną tożsamością do `security` stacka.

### 4.3 Federated Identity Credentials (FIC)

Dla każdego SP dodaj FIC ograniczony do:

- repo: `funmagsoft/movies-infrastructure`
- GitHub Environment: `dev`, `stage`, `prod`, `global`

Typowy `subject` dla environment:

`repo:funmagsoft/movies-infrastructure:environment:<ENV>`

**Rekomendacja bezpieczeństwa**:

- W GitHub ustaw Environments (dev/stage/prod) i włącz approvals dla prod.
- Włącz branch protections (np. tylko `main`).

## 5. Bootstrap – procedura szczegółowa

Bootstrap jest **jednorazowy** i rozwiązuje problem „kura i jajko”: zanim użyjesz backendu `azurerm`, musisz stworzyć Storage Account i kontenery na stan.

### 5.1 Krok A: Przygotowanie Entra ID / OIDC (manual)

1. Utwórz App registrations / SP:

- global
- dev
- stage
- prod

1. Dodaj Federated Credentials dla GitHub OIDC dla każdego SP.

1. Nadaj role zgodnie z sekcją 4.2.

> W praktyce można to zrobić Azure CLI. Jeżeli w repo jest skrypt pomocniczy w `scripts/oidc/`, użyj go. W przeciwnym razie wykonaj ręcznie zgodnie z checklistą.

Checklist (per SP):

- [ ] SP istnieje
- [ ] FIC skonfigurowany dla właściwego environment
- [ ] RBAC na RG środowiska
- [ ] RBAC do kontenera tfstate
- [ ] (dla env) read-only do `tfstate-global`

### 5.2 Krok B: Wdrożenie backendu stanu Terraform (lokalny stan)

1. Przejdź do stacka bootstrap:

```bash
cd stacks/00-bootstrap/backend-local
```

1. Wykonaj `init/plan/apply`.

- Ten stack **nie** używa backendu `azurerm` (stan lokalny) i powinien utworzyć:
  - RG backendu,
  - Storage Account,
  - kontenery `tfstate-global/dev/stage/prod`,
  - hardening Storage Account (HTTPS only, TLS min, versioning, soft delete).

1. Po `apply` zanotuj outputy:

- nazwa resource group backendu
- nazwa storage account
- lista kontenerów

### 5.3 Krok C: Wygenerowanie plików `backend.hcl` w `env/*`

Po bootstrapie generujemy `env/<env>/backend.hcl`, aby kolejne stacki mogły używać zdalnego stanu.

Jeżeli repo zawiera generator:

```bash
./scripts/generate-backends.sh
```

To skrypt:

- pobierze outputy bootstrapu,
- utworzy `env/dev/backend.hcl`, `env/stage/backend.hcl`, `env/prod/backend.hcl`, `env/global/backend.hcl`,
- ustawi właściwy `container_name` per env.

**Ważne:** klucz stanu (`key`) jest ustawiany per stack podczas `terraform init` (przez wrapper `tf.sh`).

### 5.4 Krok D: Migracja na zdalny stan (pierwsze init)

Od tego momentu każdy stack w `stacks/**` ma:

```hcl
terraform { backend "azurerm" {} }
```

A `terraform init` dostaje:

- `-backend-config=env/<env>/backend.hcl`
- `-backend-config=key=<env>/<layer>/<stack>.tfstate`

Wrapper `scripts/tf.sh` robi to automatycznie.

## 6. Kolejność wdrożeń (rekomendowana)

### 6.1 Jednorazowo

1. Bootstrap backend:

- `stacks/00-bootstrap/backend-local`

1. Globalny ACR:

- `stacks/10-global/acr`

### 6.2 Per środowisko (dev, potem stage, potem prod)

1. `stacks/20-platform/core`
1. `stacks/20-platform/aks`
1. (opcjonalnie) `stacks/20-platform/data` – tylko jeśli `enable_* = true`
1. (opcjonalnie) `stacks/20-platform/observability` – tylko jeśli `enable_observability = true`
1. `stacks/30-apps/frontend`
1. `stacks/30-apps/backend`

> Dzięki osobnym stanom per stack możesz wdrażać serwisy niezależnie i ograniczać blast radius.

## 7. Operacje day-2 (typowe działania)

### 7.1 Plan / Apply przez wrapper

Zakładamy wrapper:

```bash
./scripts/tf.sh <env> <stack> plan
./scripts/tf.sh <env> <stack> apply
```

Gdzie `<stack>` to np.:

- `10-global/acr`
- `20-platform/core`
- `20-platform/aks`
- `30-apps/frontend`

Wrapper powinien:

- wejść do właściwego katalogu `stacks/...`,
- dobrać tfvars z `env/<env>/...`,
- ustawić backend.hcl i key,
- uruchomić terraform.

### 7.2 Włączanie usług (KV/SB/Storage/Observability)

W `env/<env>/platform/data.tfvars` ustaw:

- `enable_keyvault = true`
- `enable_servicebus = true` *(Basic)*
- `enable_storage = true`

Następnie:

```bash
./scripts/tf.sh <env> 20-platform/data apply
```

Analogicznie dla monitoringu.

### 7.3 Dodanie nowego serwisu

1. Dodaj nowy stack w `stacks/30-apps/<service>`.
1. Dodaj `env/<env>/apps/<service>.tfvars`.
1. Zdecyduj, czy serwis potrzebuje KV/SB/Storage (i jakich zakresów).
1. Wdrażaj niezależnie:

```bash
./scripts/tf.sh dev 30-apps/<service> apply
```

## 8. AKS – dostęp i bezpieczeństwo

### 8.1 Publiczny AKS z allow-list

W każdym env API server ma allow-list:

- `91.150.222.105/32`

To oznacza, że `kubectl` działa tylko z tego IP (oraz ewentualnie z innych, które dodasz w przyszłości).

### 8.2 Pobranie kubeconfig

Z Twojego komputera (z dozwolonego IP):

```bash
az aks get-credentials -g rg-fms-movies-<env>-plc-01 -n aks-fms-movies-<env>-plc-01
kubectl get nodes
```

> Konkretnie nazwy RG/AKS wynikają z naming standardu i numeracji `nn`.

## 9. GitOps / Argo CD – integracja operacyjna

### 9.1 Repozytorium GitOps

Manifesty Kubernetes znajdują się w `funmagsoft/movies-gitops`.

### 9.2 Instalacja Argo CD (inicjalnie ręczna)

1. Zainstaluj Argo CD w klastrze (z Twojego IP).
1. Skonfiguruj dostęp Argo do repo `movies-gitops` (read-only; preferowane deploy key / GitHub App).

### 9.3 Bootstrap aplikacji (app-of-apps)

W `movies-gitops` struktura jest:

- `apps/` – definicje aplikacji (frontend/backend)
- `environments/<env>/` – kompozycja Argo Applications

Po instalacji Argo:

- zastosuj root application dla env (dev/stage/prod) wskazujący na `environments/<env>`.

### 9.4 Placeholdery i renderowanie

Manifesty GitOps używają placeholderów:

- `__ACR_LOGIN_SERVER__`
- `__INGRESS_PIP_NAME__`
- `__INGRESS_PIP_RG__`
- `__FRONTEND_CLIENT_ID__`
- `__BACKEND_CLIENT_ID__`

W repo infrastruktury znajduje się skrypt, który pobierze outputy Terraform i wstawi wartości do GitOps (zwykle lokalnie):

```bash
./scripts/render-gitops.sh --gitops-path ../movies-gitops --env dev
```

Następnie commit/push do `movies-gitops` i Argo zsynchronizuje zmiany.

### 9.5 Obrazy

Na start używamy:

- `movies-frontend:latest`
- `movies-backend:latest`

Po stronie pipeline aplikacji (`movies-frontend` i `movies-backend`) publikujesz obrazy do ACR.

## 10. Troubleshooting (najczęstsze)

### 10.1 Brak dostępu do AKS API

- Sprawdź, czy jesteś na IP `91.150.222.105`.
- Sprawdź authorized IP ranges w AKS.
- Sprawdź RBAC (Entra/Kubernetes).

### 10.2 Brak dostępu do stanu Terraform

- Sprawdź, czy SP ma `Storage Blob Data Contributor` do właściwego kontenera.
- Sprawdź, czy backend.hcl wskazuje na właściwy kontener.

### 10.3 Problemy z role assignments

- Upewnij się, że SP ma `Owner` lub `User Access Administrator` (wraz z Contributor) na RG env.

## 11. Bezpieczeństwo i dobre praktyki

- Traktuj `tfstate` jako dane wrażliwe (mogą zawierać identyfikatory i czasem wartości zależne od providerów).
- Kontenery `tfstate` per env ograniczają blast radius.
- Dla prod używaj GitHub Environments z approvals.
- Rozważ dodatkowo:
  - Azure Policy baseline (kolejny etap),
  - Key Vault purge protection w prod (gdy włączysz KV),
  - private endpoints dla danych (gdy dojrzeje wymaganie).

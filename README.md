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
   ./scripts/tf.sh global stacks/10-global/acr apply
   ```

3. **Wdróż platformę (per środowisko):**

   ```bash
   ./scripts/tf.sh dev stacks/20-platform/core apply
   ./scripts/tf.sh dev stacks/20-platform/aks apply
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

#### Pliki tfvars - bezpieczeństwo

Pliki `env/**/platform/*.tfvars` i `env/**/apps/*.tfvars` są **śledzone w git**, ponieważ zawierają tylko konfigurację infrastruktury (flagi, nazwy zasobów, CIDR ranges, konfigurację node pools).

**⚠️ WAŻNE: NIGDY nie dodawaj do plików tfvars:**

- Hasła, klucze API, tokeny dostępu
- Connection strings z credentials
- Private keys, certificates
- Inne wrażliwe dane (secrets)

**Dla wrażliwych danych używaj:**

- Azure Key Vault (moduł `modules/azure/keyvault`)
- Environment variables w CI/CD pipelines
- Terraform variables z `sensitive = true` przekazywane przez zmienne środowiskowe
- Azure Key Vault secrets jako data sources w kodzie Terraform

Pliki `backend.hcl` są generowane przez `./scripts/generate-backends.sh` i **nie są śledzone** w git (ignorowane przez `.gitignore`).

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

### 5.1 Krok A: Przygotowanie Entra ID / OIDC

Skrypt pomocniczy automatyzuje tworzenie Service Principals i konfigurację OIDC:

```bash
./scripts/setup-oidc.sh [--assign-roles] [--subscription-id SUB_ID]
```

**Co robi skrypt:**

1. Tworzy App Registrations / Service Principals dla: `global`, `dev`, `stage`, `prod`
2. Konfiguruje Federated Identity Credentials (FIC) dla GitHub OIDC
3. Opcjonalnie nadaje role RBAC (jeśli użyto `--assign-roles`)

**Nazewnictwo Service Principals:**

- `sp-tf-global-fms-movies`
- `sp-tf-dev-fms-movies`
- `sp-tf-stage-fms-movies`
- `sp-tf-prod-fms-movies`

**Federated Identity Credentials:**

- Subject: `repo:funmagsoft/movies-infrastructure:environment:{env}`
- Repository: `funmagsoft/movies-infrastructure`
- Environment: `dev`, `stage`, `prod`, `global`

#### Opcja 1: Uruchomienie bez `--assign-roles` (zalecane na początku)

Możesz uruchomić skrypt **przed** wykonaniem kroku 5.2 (bootstrap backendu).** Skrypt utworzy tylko Service Principals i FIC, bez przypisywania ról RBAC.

```bash
./scripts/setup-oidc.sh
```

**Wymagania:**

- Brak wymagań wstępnych - możesz uruchomić w dowolnym momencie
- Wystarczy być zalogowanym do Azure CLI (`az login`)

**Co zostanie utworzone:**

- 4 App Registrations / Service Principals (global, dev, stage, prod)
- 4 Federated Identity Credentials dla GitHub OIDC

**Następne kroki:**

- Po utworzeniu SP i FIC, role RBAC musisz przypisać ręcznie (zobacz checklistę poniżej) lub użyć opcji 2 po wykonaniu wymaganych kroków.

#### Opcja 2: Uruchomienie z `--assign-roles` (automatyczne przypisanie ról)

Skrypt automatycznie przypisze wszystkie wymagane role RBAC, ale **wymaga wykonania wcześniejszych kroków**.

```bash
./scripts/setup-oidc.sh --assign-roles
```

**Wymagania wstępne:**

1. **Krok 5.2 musi być wykonany** (bootstrap backendu):
   - Resource Group backendu tfstate (utworzony przez `stacks/00-bootstrap/backend-local`)
   - Storage Account backendu tfstate (utworzony przez `stacks/00-bootstrap/backend-local`)
   - Kontenery `tfstate-global`, `tfstate-dev`, `tfstate-stage`, `tfstate-prod` w Storage Account

   Skrypt odczytuje te zasoby z outputów Terraform stacka `stacks/00-bootstrap/backend-local`:
   - `tfstate_resource_group_name` - nazwa Resource Group backendu
   - `tfstate_storage_account_name` - nazwa Storage Account backendu

2. **Dla dev/stage/prod: Environment Resource Groups muszą istnieć:**
   - `rg-fms-movies-dev-plc-01` (utworzony przez `stacks/20-platform/core` dla środowiska dev)
   - `rg-fms-movies-stage-plc-01` (utworzony przez `stacks/20-platform/core` dla środowiska stage)
   - `rg-fms-movies-prod-plc-01` (utworzony przez `stacks/20-platform/core` dla środowiska prod)

   > **Uwaga:** Dla SP `sp-tf-global-fms-movies` role są przypisywane ręcznie do zasobów globalnych (np. ACR), więc Environment RG nie jest wymagany.

**Kolejność wykonania dla opcji 2:**

1. Wykonaj **Krok 5.2** (bootstrap backendu) - utworzy RG i Storage Account dla tfstate
2. (Opcjonalnie) Wykonaj **Krok 6.2** dla każdego środowiska (`stacks/20-platform/core`) - utworzy Environment Resource Groups
3. Uruchom `./scripts/setup-oidc.sh --assign-roles`

**Co zostanie utworzone/przypisane:**

- 4 App Registrations / Service Principals
- 4 Federated Identity Credentials
- Role RBAC dla każdego SP:
  - **Owner** na Environment Resource Group (dla dev/stage/prod)
  - **Storage Blob Data Contributor** na kontenerze tfstate (`tfstate-{env}`)
  - **Reader** na Resource Group backendu tfstate
  - **Reader** na kontenerze `tfstate-global` (dla dev/stage/prod, aby uzyskać dostęp do outputów ACR)

**Jeśli zasoby nie istnieją:**

Jeśli uruchomisz `--assign-roles` przed wykonaniem wymaganych kroków, skrypt:

- Utworzy SP i FIC (jak w opcji 1)
- Pominie przypisanie ról RBAC z komunikatem ostrzegawczym
- Wyświetli instrukcje, jak przypisać role ręcznie

#### Checklist ręcznego przypisania ról (jeśli nie używasz `--assign-roles`)

Dla każdego Service Principal (`sp-tf-{env}-fms-movies`):

- [ ] SP istnieje
- [ ] FIC skonfigurowany dla właściwego environment
- [ ] **Owner** na Environment Resource Group: `rg-fms-movies-{env}-plc-01` (dla dev/stage/prod)
- [ ] **Storage Blob Data Contributor** na kontenerze tfstate: `tfstate-{env}` w Storage Account backendu
- [ ] **Reader** na Resource Group backendu tfstate (z kroku 5.2)
- [ ] **Reader** na kontenerze `tfstate-global` (dla dev/stage/prod, aby uzyskać dostęp do outputów ACR)

### 5.2 Krok B: Wdrożenie backendu stanu Terraform (lokalny stan)

1. **Upewnij się, że jesteś zalogowany do Azure:**

```bash
az login
```

> **⚠️ WAŻNE:** Provider AzureRM (v4.50.0+) wymaga jawnego ustawienia subscription ID. Jeśli nie ustawisz subscription ID, otrzymasz błąd: `subscription ID could not be determined and was not specified`.
>
> **💡 Automatyczne ustawienie:** Skrypt `tf.sh` automatycznie ustawia `ARM_SUBSCRIPTION_ID` z Azure CLI, więc nie musisz tego robić ręcznie przy użyciu wrappera.
>
> **Dostępne opcje ustawienia subscription ID (jeśli używasz Terraform bezpośrednio):**
>
> 1. **Zmienna środowiskowa (zalecane):**
>
>    ```bash
>    export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
>    ```
>
> 2. **Zmienna Terraform:**
>
>    ```bash
>    terraform plan -var="subscription_id=$(az account show --query id -o tsv)"
>    ```
>
>    Lub ustaw na stałe w sesji:
>
>    ```bash
>    export TF_VAR_subscription_id=$(az account show --query id -o tsv)
>    ```

1. **Przejdź do stacka bootstrap:**

```bash
cd stacks/00-bootstrap/backend-local
```

1. **Wykonaj `init/plan/apply`:**

```bash
terraform init
terraform plan
terraform apply
```

Ten stack **nie** używa backendu `azurerm` (stan lokalny) i powinien utworzyć:

- Resource Group backendu (np. `rg-fms-movies-shared-plc-01`)
- Storage Account (constrained name, np. `st<...>tf<...>`)
- Kontenery `tfstate-global`, `tfstate-dev`, `tfstate-stage`, `tfstate-prod`
- Hardening Storage Account (HTTPS only, TLS min, versioning, soft delete)

1. **Po `apply` zanotuj outputy:**

```bash
terraform output
```

Zapisz:

- nazwa resource group backendu (`tfstate_resource_group_name`)
- nazwa storage account (`tfstate_storage_account_name`)
- lista kontenerów (`containers`)

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

#### Wymagane uprawnienia dla lokalnego użytkownika

Podczas pierwszego `terraform init` z backendem `azurerm` możesz napotkać błąd **403 (AuthorizationPermissionMismatch)**. Oznacza to, że Twoje konto Azure nie ma wymaganych uprawnień do kontenera z stanem Terraform.

**Wymagane uprawnienia:**

- **Storage Blob Data Contributor** na kontenerze tfstate dla danego środowiska (np. `tfstate-global`, `tfstate-dev`)
- **Reader** na Resource Group backendu tfstate (opcjonalnie, ale zalecane)

**Jak przypisać uprawnienia:**

> **💡 Zalecane:** Użyj skryptu `assign-tfstate-permissions.sh`, który automatycznie pobiera informacje z bootstrap stack i przypisuje wymagane uprawnienia:
>
> ```bash
> # Dla wszystkich środowisk (global, dev, stage, prod) - zalecane
> ./scripts/assign-tfstate-permissions.sh --all-environments --dry-run  # najpierw sprawdź
> ./scripts/assign-tfstate-permissions.sh --all-environments           # następnie wykonaj
>
> # Dla pojedynczego środowiska
> ./scripts/assign-tfstate-permissions.sh --environment global --dry-run
> ./scripts/assign-tfstate-permissions.sh --environment global
> ./scripts/assign-tfstate-permissions.sh --environment dev
> ./scripts/assign-tfstate-permissions.sh --environment stage
> ./scripts/assign-tfstate-permissions.sh --environment prod
>
> # Z określonym użytkownikiem
> ./scripts/assign-tfstate-permissions.sh --all-environments --user-id "12345678-1234-1234-1234-123456789012"
>
> # Na poziomie Storage Account (wszystkie kontenery)
> ./scripts/assign-tfstate-permissions.sh --environment global --scope storage-account
> ```
>
> Skrypt automatycznie:
>
> - Pobiera informacje o Storage Account z bootstrap stack
> - Pobiera ID zalogowanego użytkownika (lub używa podanego `--user-id`)
> - Sprawdza, czy rola już istnieje
> - Przypisuje rolę `Storage Blob Data Contributor` na odpowiednim kontenerze
> - Weryfikuje przypisanie roli

**Ręczne przypisanie uprawnień (alternatywa):**

- **Sprawdź, kim jesteś zalogowany:**

```bash
az account show --query user
```

- **Pobierz ID Storage Account i kontenera:**

```bash
# Dla środowiska global
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name stfmsmovxplcb3d001tf \
  --resource-group rg-fms-movies-shared-plc-01 \
  --query id -o tsv)

CONTAINER_ID="${STORAGE_ACCOUNT_ID}/blobServices/default/containers/tfstate-global"

# Dla środowisk dev/stage/prod użyj odpowiedniego kontenera:
# CONTAINER_ID="${STORAGE_ACCOUNT_ID}/blobServices/default/containers/tfstate-dev"
```

- **Pobierz ID użytkownika:**

```bash
USER_ID=$(az ad signed-in-user show --query id -o tsv)
```

- **Przypisz rolę Storage Blob Data Contributor:**

```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "${USER_ID}" \
  --scope "${CONTAINER_ID}"
```

**Alternatywnie** (jeśli masz uprawnienia Owner/User Access Administrator), możesz przypisać rolę na poziomie Storage Account (będzie dotyczyć wszystkich kontenerów):

```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "${USER_ID}" \
  --scope "${STORAGE_ACCOUNT_ID}"
```

**Weryfikacja:**

```bash
az role assignment list \
  --assignee "${USER_ID}" \
  --scope "${CONTAINER_ID}" \
  --output table
```

> **Uwaga:** Jeśli nie masz uprawnień do przypisania ról, poproś administratora subskrypcji o przypisanie roli `Storage Blob Data Contributor` na odpowiednim kontenerze tfstate dla Twojego konta użytkownika.

## 6. Kolejność wdrożeń (rekomendowana)

### 6.1 Jednorazowo

> **Uwaga:** Jeśli wykonujesz pełny bootstrap po raz pierwszy, kroki 1-2 zostały już wykonane w sekcji 5 (Bootstrap – procedura szczegółowa). Przejdź do kroku 3.

1. **Bootstrap backend** (jeśli jeszcze nie wykonany):

   Wykonaj kroki z sekcji **5.2 Krok B: Wdrożenie backendu stanu Terraform**:

   ```bash
   cd stacks/00-bootstrap/backend-local
   # Ustaw ARM_SUBSCRIPTION_ID (wymagane dla AzureRM provider v4.50.0+)
   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   terraform init
   terraform plan
   terraform apply
   cd ../../..
   ```

   > **💡 Uwaga:** Dla stacków używających `tf.sh` wrappera, `ARM_SUBSCRIPTION_ID` jest automatycznie ustawiane z Azure CLI. Ręczne ustawienie jest wymagane tylko dla stacka bootstrap, który używa lokalnego stanu.

   Następnie wygeneruj pliki `backend.hcl` (sekcja **5.3 Krok C**):

   ```bash
   ./scripts/generate-backends.sh
   ```

2. **Globalny ACR:**

   ```bash
   ./scripts/tf.sh global stacks/10-global/acr apply
   ```

   > **Uwaga:** Stack `stacks/10-global/acr` używa środowiska `global` i backendu `azurerm` (zdalny stan w kontenerze `tfstate-global`).

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
./scripts/tf.sh <env> <stack> init
./scripts/tf.sh <env> <stack> output
./scripts/tf.sh <env> <stack> destroy
./scripts/tf.sh <env> <stack> force-unlock <lock-id>
```

Gdzie `<stack>` to np.:

- `10-global/acr`
- `20-platform/core`
- `20-platform/aks`
- `30-apps/frontend`

Wrapper automatycznie:

- ustawia `ARM_SUBSCRIPTION_ID` z Azure CLI (jeśli nie jest ustawione),
- wchodzi do właściwego katalogu `stacks/...`,
- dobiera tfvars z `env/<env>/backend.auto.tfvars.json`,
- ustawia backend.hcl i key,
- uruchamia terraform.

**Dostępne akcje:**

- `init` - inicjalizuje Terraform z backendem
- `plan` - generuje plan zmian
- `apply` - aplikuje zmiany
- `destroy` - niszczy zasoby (z potwierdzeniem)
- `output` - wyświetla outputy
- `force-unlock <lock-id>` - odblokowuje zablokowany stan (używaj ostrożnie!)

**Przykład użycia force-unlock:**

Jeśli otrzymasz błąd `Error acquiring the state lock`, możesz odblokować stan:

```bash
# Lock ID jest widoczny w komunikacie błędu
./scripts/tf.sh global stacks/10-global/acr force-unlock 209643d6-2f1c-de36-b16d-ac13563f13e7
```

> **⚠️ Uwaga:** Używaj `force-unlock` tylko wtedy, gdy jesteś pewien, że lock jest nieaktualny (np. po przerwanej operacji). Jeśli inna operacja Terraform jest w toku, odblokowanie może spowodować konflikt.

### 7.2 Włączanie usług (KV/SB/Storage/Observability)

W `env/<env>/platform/data.tfvars` ustaw:

- `enable_keyvault = true`
- `enable_servicebus = true` *(Basic)*
- `enable_storage = true`

Następnie:

```bash
./scripts/tf.sh <env> stacks/20-platform/data apply
```

Analogicznie dla monitoringu.

### 7.3 Dodanie nowego serwisu

1. Dodaj nowy stack w `stacks/30-apps/<service>`.
1. Dodaj `env/<env>/apps/<service>.tfvars`.
1. Zdecyduj, czy serwis potrzebuje KV/SB/Storage (i jakich zakresów).
1. Wdrażaj niezależnie:

```bash
./scripts/tf.sh dev stacks/30-apps/<service> apply
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

### 10.2 Problemy z dostępem do stanu Terraform

**Błąd 403 (AuthorizationPermissionMismatch):**

- Sprawdź, czy masz `Storage Blob Data Contributor` na właściwym kontenerze tfstate.
- Użyj skryptu `assign-tfstate-permissions.sh` do przypisania uprawnień (patrz sekcja 5.4).
- Sprawdź, czy backend.hcl wskazuje na właściwy kontener.

**Błąd "state blob is already locked":**

Jeśli otrzymasz błąd `Error acquiring the state lock`, oznacza to, że poprzednia operacja Terraform nie zakończyła się poprawnie i pozostawiła lock.

**Rozwiązanie:**

1. Sprawdź, czy nie ma innej operacji Terraform w toku.
2. Jeśli lock jest nieaktualny, odblokuj go używając `force-unlock`:

```bash
# Lock ID jest widoczny w komunikacie błędu
./scripts/tf.sh <env> <stack> force-unlock <lock-id>
```

**Przykład:**

```bash
./scripts/tf.sh global stacks/10-global/acr force-unlock 209643d6-2f1c-de36-b16d-ac13563f13e7
```

> **⚠️ Uwaga:** Używaj `force-unlock` tylko wtedy, gdy jesteś pewien, że lock jest nieaktualny. Jeśli inna operacja Terraform jest w toku, odblokowanie może spowodować konflikt i uszkodzenie stanu.

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

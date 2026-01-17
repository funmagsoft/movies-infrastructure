# Procedury wdrożenia

## Wymagania wstępne

### Narzędzia

- Terraform (zgodny z wersją określoną w `modules/standards/versions.tf` lub `scripts/terraform-versions-reference.tf`)
- Azure CLI (`az`)
- Git
- (opcjonalnie) `jq`

### Dostęp i uprawnienia

Zakładamy **jedną subskrypcję** dla wszystkich env.

Minimalnie potrzebujesz uprawnień, aby:

- utworzyć Storage Account i kontenery na tfstate,
- utworzyć App registrations / Service principals oraz skonfigurować OIDC (federated credentials),
- nadać role RBAC (w tym role assignments dla managed identities).

## Bootstrap – procedura szczegółowa

Bootstrap jest **jednorazowy** i rozwiązuje problem „kura i jajko”: zanim użyjesz backendu `azurerm`, musisz stworzyć Storage Account i kontenery na stan.

### Krok A: Przygotowanie Entra ID / OIDC (manual)

1. Utwórz App registrations / SP:

- global
- dev
- stage
- prod

1. Dodaj Federated Credentials dla GitHub OIDC dla każdego SP.

1. Nadaj role zgodnie z sekcją 4.2 w ARCHITECTURE.md.

> W praktyce można to zrobić Azure CLI. Jeżeli w repo jest skrypt pomocniczy w `scripts/oidc/`, użyj go. W przeciwnym razie wykonaj ręcznie zgodnie z checklistą.

Checklist (per SP):

- [ ] SP istnieje
- [ ] FIC skonfigurowany dla właściwego environment
- [ ] RBAC na RG środowiska
- [ ] RBAC do kontenera tfstate
- [ ] (dla env) read-only do `tfstate-global`

### Krok B: Wdrożenie backendu stanu Terraform (lokalny stan)

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

### Krok C: Wygenerowanie plików `backend.hcl` w `env/*`

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

### Krok D: Migracja na zdalny stan (pierwsze init)

Od tego momentu każdy stack w `stacks/**` ma:

```hcl
terraform { backend "azurerm" {} }
```

A `terraform init` dostaje:

- `-backend-config=env/<env>/backend.hcl`
- `-backend-config=key=<env>/<layer>/<stack>.tfstate`

Wrapper `scripts/tf.sh` robi to automatycznie.

## Kolejność wdrożeń (rekomendowana)

### Jednorazowo

1. Bootstrap backend:

- `stacks/00-bootstrap/backend-local`

1. Globalny ACR:

- `stacks/10-global/acr`

### Per środowisko (dev, potem stage, potem prod)

1. `stacks/20-platform/core`
1. `stacks/20-platform/aks`
1. (opcjonalnie) `stacks/20-platform/data` – tylko jeśli `enable_* = true`
1. (opcjonalnie) `stacks/20-platform/observability` – tylko jeśli `enable_observability = true`
1. `stacks/20-platform/security` – opcjonalnie dla prod
1. `stacks/30-apps/frontend`
1. `stacks/30-apps/backend`

> Dzięki osobnym stanom per stack możesz wdrażać serwisy niezależnie i ograniczać blast radius.

## Operacje day-2 (typowe działania)

### Plan / Apply przez wrapper

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

### Włączanie usług (KV/SB/Storage/Observability)

W `env/<env>/platform/data.tfvars` ustaw:

- `enable_keyvault = true`
- `enable_servicebus = true` *(Basic)*
- `enable_storage = true`

Następnie:

```bash
./scripts/tf.sh <env> 20-platform/data apply
```

Analogicznie dla monitoringu.

### Dodanie nowego serwisu

1. Dodaj nowy stack w `stacks/30-apps/<service>`.
1. Dodaj `env/<env>/apps/<service>.tfvars`.
1. Zdecyduj, czy serwis potrzebuje KV/SB/Storage (i jakich zakresów).
1. Wdrażaj niezależnie:

```bash
./scripts/tf.sh dev 30-apps/<service> apply
```

## AKS – dostęp i bezpieczeństwo

### Publiczny AKS z allow-list

W każdym env API server ma allow-list:

- `91.150.222.105/32`

To oznacza, że `kubectl` działa tylko z tego IP (oraz ewentualnie z innych, które dodasz w przyszłości).

### Pobranie kubeconfig

Z Twojego komputera (z dozwolonego IP):

```bash
az aks get-credentials -g rg-fms-movies-<env>-plc-01 -n aks-fms-movies-<env>-plc-01
kubectl get nodes
```

> Konkretnie nazwy RG/AKS wynikają z naming standardu i numeracji `nn`.

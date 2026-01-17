# Operacje i runbooki

## GitOps / Argo CD – integracja operacyjna

### Repozytorium GitOps

Manifesty Kubernetes znajdują się w `funmagsoft/movies-gitops`.

### Instalacja Argo CD (inicjalnie ręczna)

1. Zainstaluj Argo CD w klastrze (z Twojego IP).
1. Skonfiguruj dostęp Argo do repo `movies-gitops` (read-only; preferowane deploy key / GitHub App).

### Bootstrap aplikacji (app-of-apps)

W `movies-gitops` struktura jest:

- `apps/` – definicje aplikacji (frontend/backend)
- `environments/<env>/` – kompozycja Argo Applications

Po instalacji Argo:

- zastosuj root application dla env (dev/stage/prod) wskazujący na `environments/<env>`.

### Placeholdery i renderowanie

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

### Obrazy

Na start używamy:

- `movies-frontend:latest`
- `movies-backend:latest`

Po stronie pipeline aplikacji (`movies-frontend` i `movies-backend`) publikujesz obrazy do ACR.

## Troubleshooting

### Brak dostępu do AKS API

- Sprawdź, czy jesteś na IP `91.150.222.105`.
- Sprawdź authorized IP ranges w AKS.
- Sprawdź RBAC (Entra/Kubernetes).

### Brak dostępu do stanu Terraform

- Sprawdź, czy SP ma `Storage Blob Data Contributor` do właściwego kontenera.
- Sprawdź, czy backend.hcl wskazuje na właściwy kontener.
- Sprawdź, czy używasz właściwego environment w GitHub Actions.

### Problemy z role assignments

- Upewnij się, że SP ma `Owner` lub `User Access Administrator` (wraz z Contributor) na RG env.
- Sprawdź, czy managed identity istnieje przed przypisaniem ról.

### Problemy z Key Vault

- Sprawdź, czy purge protection jest włączone dla prod (nie można go wyłączyć).
- Sprawdź access policies i role assignments.
- Sprawdź, czy soft delete retention period nie wygasł.

### Problemy z synchronizacją wersji Terraform

```bash
# Sprawdź spójność wersji
./scripts/check-versions.sh

# Zsynchronizuj wszystkie wersje
./scripts/sync-versions.sh
```

## Bezpieczeństwo i dobre praktyki

- Traktuj `tfstate` jako dane wrażliwe (mogą zawierać identyfikatory i czasem wartości zależne od providerów).
- Kontenery `tfstate` per env ograniczają blast radius.
- Dla prod używaj GitHub Environments z approvals.
- Key Vault purge protection jest automatycznie włączone dla prod.
- Rozważ dodatkowo:
  - Azure Policy baseline (kolejny etap),
  - private endpoints dla danych (gdy dojrzeje wymaganie),
  - regularne przeglądy RBAC.

## Monitoring i metryki

### Terraform state size

Monitoruj rozmiar plików stanu w Storage Account. Duże pliki mogą spowolnić operacje.

### Deployment frequency

Śledź częstotliwość wdrożeń per środowisko. Wysoka częstotliwość może wskazywać na problemy.

### Failed deployments

Konfiguruj alerty na failed deployments w GitHub Actions.

## Backup i disaster recovery

### Terraform state

- Storage Account ma włączone versioning i soft delete.
- Regularnie eksportuj stan dla krytycznych stacków (prod).

### Konfiguracja

- Wszystka konfiguracja jest w repozytorium Git.
- Taguj wersje przed większymi zmianami.

## Aktualizacje

### Terraform version

1. Zaktualizuj `scripts/terraform-versions-reference.tf`
2. Uruchom `./scripts/sync-versions.sh`
3. Przetestuj w dev przed aktualizacją prod

### Provider versions

1. Zaktualizuj wersję w `scripts/terraform-versions-reference.tf`
2. Uruchom `./scripts/sync-versions.sh`
3. Przetestuj w dev
4. Sprawdź breaking changes w changelog providera

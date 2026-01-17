# Troubleshooting Guide

## Najczęstsze problemy i rozwiązania

### 1. Brak dostępu do AKS API

**Objawy:**

- `kubectl` nie może połączyć się z klastrem
- Błąd: "Unable to connect to the server"

**Rozwiązanie:**

1. Sprawdź, czy jesteś na IP `91.150.222.105/32` (lub innym z allow-list)
2. Sprawdź authorized IP ranges w AKS:

   ```bash
   az aks show -g rg-fms-movies-<env>-plc-01 -n aks-fms-movies-<env>-plc-01 --query apiServerAccessProfile.authorizedIpRanges
   ```

3. Sprawdź RBAC (Entra/Kubernetes)
4. Sprawdź, czy masz odpowiednie uprawnienia w Azure

### 2. Brak dostępu do stanu Terraform

**Objawy:**

- `terraform init` kończy się błędem
- Błąd: "Failed to get existing workspaces"

**Rozwiązanie:**

1. Sprawdź, czy SP ma `Storage Blob Data Contributor` do właściwego kontenera
2. Sprawdź, czy `backend.hcl` wskazuje na właściwy kontener:

   ```bash
   cat env/<env>/backend.hcl
   ```

3. Sprawdź, czy Storage Account istnieje
4. Sprawdź, czy używasz właściwego environment w GitHub Actions

### 3. Problemy z role assignments

**Objawy:**

- Błąd podczas `terraform apply`: "Authorization failed"
- Managed identity nie może uzyskać dostępu do zasobów

**Rozwiązanie:**

1. Upewnij się, że SP ma `Owner` lub `User Access Administrator` na RG env
2. Sprawdź, czy managed identity istnieje przed przypisaniem ról
3. Sprawdź, czy zakres role assignment jest poprawny
4. Sprawdź logi Azure Activity Log dla szczegółów błędu

### 4. Problemy z Key Vault

**Objawy:**

- Nie można włączyć/wyłączyć purge protection
- Błąd: "Purge protection cannot be disabled"

**Rozwiązanie:**

1. Purge protection w prod nie może być wyłączone (to feature, nie bug)
2. Sprawdź access policies i role assignments
3. Sprawdź, czy soft delete retention period nie wygasł
4. Dla dev/stage możesz wyłączyć purge protection tylko jeśli nie było włączone

### 5. Problemy z synchronizacją wersji Terraform

**Objawy:**

- Różne moduły używają różnych wersji
- Błędy kompatybilności

**Rozwiązanie:**

```bash
# Sprawdź spójność wersji
./scripts/check-versions.sh

# Zsynchronizuj wszystkie wersje
./scripts/sync-versions.sh

# Zweryfikuj
./scripts/check-versions.sh
```

### 6. Błędy walidacji zmiennych

**Objawy:**

- `terraform validate` kończy się błędem
- Błąd: "Invalid value for variable"

**Rozwiązanie:**

1. Sprawdź komunikaty błędów walidacji - zawierają szczegóły
2. Sprawdź wartości w `env/<env>/*.tfvars`
3. Sprawdź dokumentację zmiennych w `variables.tf`
4. Upewnij się, że wartości spełniają wymagania (np. format IP, zakresy liczb)

### 7. Problemy z GitHub Actions

**Objawy:**

- Workflow kończy się błędem
- Brak uprawnień do Azure

**Rozwiązanie:**

1. Sprawdź, czy GitHub Environment jest poprawnie skonfigurowany
2. Sprawdź, czy Federated Identity Credential jest poprawnie ustawiony
3. Sprawdź, czy Service Principal ma odpowiednie uprawnienia
4. Sprawdź logi workflow w GitHub Actions

### 8. Problemy z private endpoints

**Objawy:**

- Zasoby nie mogą połączyć się z usługami Azure
- Timeout errors

**Rozwiązanie:**

1. Sprawdź, czy private endpoints są wdrożone
2. Sprawdź DNS resolution
3. Sprawdź Network Security Groups
4. Sprawdź, czy zasoby są w odpowiedniej sieci

## Debugging tips

### Włączanie debugowania Terraform

```bash
export TF_LOG=DEBUG
terraform plan
```

### Sprawdzanie stanu Terraform

```bash
# Lista zasobów w stanie
terraform state list

# Szczegóły zasobu
terraform state show <resource_address>

# Import zasobu
terraform import <resource_address> <resource_id>
```

### Sprawdzanie outputów

```bash
# Z stacka
cd stacks/<stack>
terraform output

# Z remote state
terraform output -state=../../env/<env>/<stack>.tfstate
```

## Kontakty i wsparcie

- Dokumentacja: `docs/`
- Skrypty pomocnicze: `scripts/`
- Issues: GitHub Issues w repozytorium

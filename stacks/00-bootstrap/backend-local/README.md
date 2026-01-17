# Bootstrap: Terraform state backend

This stack creates an Azure Storage Account + containers for Terraform state.

## What it creates

- Resource Group: `rg-fms-movies-shared-plc-01`
- Storage Account (constrained name): `st<...>tf<...>`
- Containers:
  - `tfstate-global`
  - `tfstate-dev`
  - `tfstate-stage`
  - `tfstate-prod`

## Security settings

- HTTPS only
- TLS 1.2 minimum
- Blob versioning enabled
- Soft delete enabled

## One-time procedure

1) Login to Azure:

```bash
az login
az account set --subscription <SUBSCRIPTION_ID>
```

2) Apply bootstrap:

```bash
cd stacks/00-bootstrap/backend-local
terraform init
terraform apply
```

3) Generate backend configs:

```bash
cd ../../..
./scripts/generate-backends.sh
```

## GitHub Actions OIDC model

Recommended identities:

- `sp-tf-global-fms-movies` → `tfstate-global`
- `sp-tf-dev-fms-movies` → `tfstate-dev`
- `sp-tf-stage-fms-movies` → `tfstate-stage`
- `sp-tf-prod-fms-movies` → `tfstate-prod`

Each SP:
- has a Federated Identity Credential (FIC) bound to GitHub Environment (`global|dev|stage|prod`)
- has `Storage Blob Data Contributor` on its own state container
- has `Owner` on its own environment RG (and enough rights to create role assignments)

Because ACR is shared, env SPs also need permission to assign `AcrPull` on the shared ACR scope.

## Notes

- This bootstrap stack intentionally uses **local Terraform state**.
- After bootstrap, all other stacks use the AzureRM backend.

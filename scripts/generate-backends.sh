#!/usr/bin/env bash
set -euo pipefail

# Error handling functions
error_exit() {
  echo "❌ Error: $1" >&2
  exit 1
}

info() {
  echo "ℹ️  $1" >&2
}

# Check dependencies
if ! command -v terraform &> /dev/null; then
  error_exit "Terraform is not installed or not in PATH"
fi

if ! command -v jq &> /dev/null; then
  error_exit "jq is not installed. Please install jq to use this script."
fi

BOOTSTRAP_DIR="stacks/00-bootstrap/backend-local"

if [[ ! -d "${BOOTSTRAP_DIR}" ]]; then
  error_exit "Bootstrap stack not found at ${BOOTSTRAP_DIR}"
fi

info "Reading outputs from bootstrap stack..."

pushd "${BOOTSTRAP_DIR}" >/dev/null
trap 'popd >/dev/null' EXIT

if ! terraform init >/dev/null 2>&1; then
  error_exit "Failed to initialize Terraform in bootstrap stack"
fi

# We expect bootstrap already applied; outputs should exist
if ! OUT_JSON=$(terraform output -json 2>/dev/null); then
  error_exit "Bootstrap stack outputs not found. Please run 'terraform apply' in ${BOOTSTRAP_DIR} first."
fi

TFSTATE_RG=$(echo "${OUT_JSON}" | jq -r '.tfstate_resource_group_name.value // empty')
TFSTATE_SA=$(echo "${OUT_JSON}" | jq -r '.tfstate_storage_account_name.value // empty')

if [[ -z "${TFSTATE_RG}" ]] || [[ -z "${TFSTATE_SA}" ]]; then
  error_exit "Failed to read required outputs from bootstrap stack. Make sure bootstrap is applied."
fi

popd >/dev/null
trap - EXIT

info "Found:"
info "  Resource Group: ${TFSTATE_RG}"
info "  Storage Account: ${TFSTATE_SA}"

info "Creating backend configuration files..."

mkdir -p env/global env/dev env/stage env/prod

write_backend() {
  local env="$1"
  local container="$2"
  local file="env/${env}/backend.hcl"
  
  if ! cat > "${file}" <<EOF
resource_group_name  = "${TFSTATE_RG}"
storage_account_name = "${TFSTATE_SA}"
container_name       = "${container}"
use_azuread_auth     = true
EOF
  then
    error_exit "Failed to write ${file}"
  fi
  
  info "  Created ${file}"
}

write_backend "global" "tfstate-global"
write_backend "dev" "tfstate-dev"
write_backend "stage" "tfstate-stage"
write_backend "prod" "tfstate-prod"

# Also write backend.auto.tfvars.json for each env with tfstate metadata
info "Creating backend.auto.tfvars.json files..."

for env in global dev stage prod; do
  local file="env/${env}/backend.auto.tfvars.json"
  if ! cat > "${file}" <<EOF
{
  "tfstate_resource_group_name": "${TFSTATE_RG}",
  "tfstate_storage_account_name": "${TFSTATE_SA}"
}
EOF
  then
    error_exit "Failed to write ${file}"
  fi
  info "  Created ${file}"
done

echo "✅ Generated backend configuration files for all environments."

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

# Renders placeholders in ../movies-gitops for a given environment.
# Usage: ./scripts/render-gitops.sh <dev|stage|prod>

ENV_NAME=${1:-}
if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <dev|stage|prod>" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  $0 dev" >&2
  exit 1
fi

# Validate environment
if [[ ! "${ENV_NAME}" =~ ^(dev|stage|prod)$ ]]; then
  error_exit "Invalid environment: ${ENV_NAME}. Must be one of: dev, stage, prod"
fi

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
  error_exit "Terraform is not installed or not in PATH"
fi

GITOPS_DIR="../movies-gitops"
if [[ ! -d "${GITOPS_DIR}" ]]; then
  error_exit "movies-gitops repo not found at ${GITOPS_DIR}. Please clone it first."
fi

TARGET_DIR="${GITOPS_DIR}/environments/${ENV_NAME}"
if [[ ! -d "${TARGET_DIR}" ]]; then
  error_exit "Target directory not found: ${TARGET_DIR}"
fi

# Read outputs from stacks with error handling
read_output() {
  local stack_path="$1"
  local key="$2"
  
  if [[ ! -d "${stack_path}" ]]; then
    error_exit "Stack path not found: ${stack_path}"
  fi
  
  if ! (cd "${stack_path}" && terraform output -raw "${key}" 2>/dev/null); then
    error_exit "Failed to read output '${key}' from ${stack_path}. Make sure the stack is deployed."
  fi
}

info "Reading outputs from Terraform stacks..."

# ACR login server from global
info "Reading ACR login server..."
ACR_LOGIN_SERVER=$(read_output "stacks/10-global/acr" "acr_login_server") || error_exit "Failed to read ACR login server"

# Static PIP params from env AKS stack
info "Reading AKS ingress Public IP..."
PIP_NAME=$(read_output "stacks/20-platform/aks" "ingress_public_ip_name") || error_exit "Failed to read Public IP name"
PIP_RG=$(read_output "stacks/20-platform/aks" "ingress_public_ip_resource_group") || error_exit "Failed to read Public IP resource group"

# Workload Identity client IDs from app stacks
info "Reading Workload Identity client IDs..."
FRONTEND_CLIENT_ID=$(read_output "stacks/30-apps/frontend" "client_id") || error_exit "Failed to read frontend client ID"
BACKEND_CLIENT_ID=$(read_output "stacks/30-apps/backend" "client_id") || error_exit "Failed to read backend client ID"

info "All outputs read successfully"

substitute() {
  local file="$1"
  if [[ ! -f "${file}" ]]; then
    info "Skipping non-existent file: ${file}"
    return
  fi
  
  if ! sed -i.bak \
    -e "s|__ACR_LOGIN_SERVER__|${ACR_LOGIN_SERVER}|g" \
    -e "s|__PIP_NAME__|${PIP_NAME}|g" \
    -e "s|__PIP_RESOURCE_GROUP__|${PIP_RG}|g" \
    -e "s|__FRONTEND_CLIENT_ID__|${FRONTEND_CLIENT_ID}|g" \
    -e "s|__BACKEND_CLIENT_ID__|${BACKEND_CLIENT_ID}|g" \
    "${file}"; then
    error_exit "Failed to substitute placeholders in ${file}"
  fi
  rm -f "${file}.bak"
}

info "Rendering placeholders in ${TARGET_DIR}..."

# Replace in all YAML under env
FILES_FOUND=0
while IFS= read -r -d '' f; do
  substitute "$f"
  ((FILES_FOUND++))
done < <(find "$TARGET_DIR" -type f -name '*.yaml' -print0 2>/dev/null || true)

# Also replace in platform kustomizations
if [[ -d "${GITOPS_DIR}/platform" ]]; then
  info "Rendering placeholders in platform kustomizations..."
  while IFS= read -r -d '' f; do
    substitute "$f"
    ((FILES_FOUND++))
  done < <(find "${GITOPS_DIR}/platform" -type f -name '*.yaml' -print0 2>/dev/null || true)
fi

if [[ ${FILES_FOUND} -eq 0 ]]; then
  error_exit "No YAML files found to process"
fi

echo "✅ Rendered placeholders for env=${ENV_NAME} in ${FILES_FOUND} file(s)."

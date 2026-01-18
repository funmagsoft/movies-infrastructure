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

success() {
  echo "✅ $1" >&2
}

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
  error_exit "Azure CLI is not installed or not in PATH. Please install Azure CLI."
fi

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
  error_exit "Terraform is not installed or not in PATH. Please install Terraform >= 1.6.0"
fi

ENV_NAME=${1:-}

if [[ -z "${ENV_NAME}" ]]; then
  echo "Usage: $0 <dev|stage|prod>" >&2
  echo "" >&2
  echo "Downloads AKS kubeconfig to a local file (kubeconfig-{env})" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 dev" >&2
  echo "  $0 prod" >&2
  exit 1
fi

# Validate environment name
if [[ ! "${ENV_NAME}" =~ ^(dev|stage|prod)$ ]]; then
  error_exit "Invalid environment: ${ENV_NAME}. Must be one of: dev, stage, prod"
fi

# Set ARM_SUBSCRIPTION_ID if not already set
if [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  if az account show &>/dev/null; then
    export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)
    if [[ -n "${ARM_SUBSCRIPTION_ID}" ]]; then
      info "Auto-set ARM_SUBSCRIPTION_ID from Azure CLI: ${ARM_SUBSCRIPTION_ID}"
    fi
  fi
fi

# Validate ARM_SUBSCRIPTION_ID is set
if [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  error_exit "ARM_SUBSCRIPTION_ID is not set. Please run 'az login' and 'az account set --subscription <ID>', or set ARM_SUBSCRIPTION_ID environment variable."
fi

STACK_PATH="stacks/20-platform/aks"
KUBECONFIG_FILE="kubeconfig-${ENV_NAME}"

# Check if stack exists
if [[ ! -d "${STACK_PATH}" ]]; then
  error_exit "Stack path not found: ${STACK_PATH}"
fi

# Backend config location
BACKEND_HCL="env/${ENV_NAME}/backend.hcl"
if [[ ! -f "${BACKEND_HCL}" ]]; then
  error_exit "Backend config not found: ${BACKEND_HCL}. Run ./scripts/generate-backends.sh after bootstrap."
fi

# State key convention
KEY="${ENV_NAME}/platform/aks.tfstate"

pushd "${STACK_PATH}" >/dev/null

# Trap to ensure we popd on exit
trap 'popd >/dev/null' EXIT

# Calculate relative path from stack directory to repo root
STACK_DEPTH=$(echo "${STACK_PATH}" | tr '/' '\n' | wc -l | tr -d ' ')
REL_PATH_TO_ROOT=""
for ((i=1; i<=STACK_DEPTH; i++)); do
  REL_PATH_TO_ROOT="../${REL_PATH_TO_ROOT}"
done
REL_PATH_TO_ROOT="${REL_PATH_TO_ROOT%/}"

info "Environment: ${ENV_NAME}"
info "Stack: ${STACK_PATH}"
info "State key: ${KEY}"

# Initialize Terraform if needed
info "Initializing Terraform (if needed)..."
terraform init -backend-config="${REL_PATH_TO_ROOT}/${BACKEND_HCL}" -backend-config="key=${KEY}" -upgrade >/dev/null 2>&1 || true

# Read AKS name from Terraform outputs
info "Reading AKS configuration from Terraform outputs..."

AKS_NAME=$(terraform output -raw aks_name 2>/dev/null || error_exit "Failed to read AKS name. Make sure the AKS stack is deployed.")

# Get resource group from core stack (AKS is in the same resource group)
info "Reading resource group from core stack..."
CORE_STACK_PATH="${REL_PATH_TO_ROOT}/stacks/20-platform/core"
if [[ ! -d "${CORE_STACK_PATH}" ]]; then
  error_exit "Core stack not found: ${CORE_STACK_PATH}"
fi

pushd "${CORE_STACK_PATH}" >/dev/null
CORE_KEY="${ENV_NAME}/platform/core.tfstate"
terraform init -backend-config="${REL_PATH_TO_ROOT}/${BACKEND_HCL}" -backend-config="key=${CORE_KEY}" -upgrade >/dev/null 2>&1 || true
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || error_exit "Failed to read resource group from core stack. Make sure the core stack is deployed.")
popd >/dev/null

info "AKS Name: ${AKS_NAME}"
info "Resource Group: ${RESOURCE_GROUP}"

# Get kubeconfig
info "Downloading kubeconfig..."
KUBECONFIG_PATH="${REL_PATH_TO_ROOT}/${KUBECONFIG_FILE}"

if az aks get-credentials \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${AKS_NAME}" \
  --file "${KUBECONFIG_PATH}" \
  --overwrite-existing >/dev/null 2>&1; then
  success "Kubeconfig saved to: ${KUBECONFIG_PATH}"
  echo ""
  echo "To use this kubeconfig, set KUBECONFIG environment variable:"
  echo "  export KUBECONFIG=\$(pwd)/${KUBECONFIG_FILE}"
  echo ""
  echo "Or use kubectl with --kubeconfig flag:"
  echo "  kubectl --kubeconfig=${KUBECONFIG_FILE} get nodes"
else
  error_exit "Failed to download kubeconfig. Make sure you have access to the AKS cluster."
fi

popd >/dev/null
trap - EXIT

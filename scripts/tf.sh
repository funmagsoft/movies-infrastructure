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

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
  error_exit "Terraform is not installed or not in PATH. Please install Terraform >= 1.6.0"
fi

ENV_NAME=${1:-}
STACK_PATH=${2:-}
ACTION=${3:-}

if [[ -z "${ENV_NAME}" || -z "${STACK_PATH}" || -z "${ACTION}" ]]; then
  echo "Usage: $0 <env|global> <stack-path> <init|plan|apply|destroy|output> [extra args...]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 dev stacks/20-platform/core plan" >&2
  echo "  $0 global stacks/10-global/acr apply" >&2
  exit 1
fi
shift 3

# Validate environment name
if [[ "${ENV_NAME}" != "global" ]] && [[ ! "${ENV_NAME}" =~ ^(dev|stage|prod)$ ]]; then
  error_exit "Invalid environment: ${ENV_NAME}. Must be one of: dev, stage, prod, global"
fi

# Validate stack path
if [[ ! -d "${STACK_PATH}" ]]; then
  error_exit "Stack path not found: ${STACK_PATH}"
fi

# Check if stack has Terraform files
if [[ ! -f "${STACK_PATH}/main.tf" ]] && [[ -z "$(find "${STACK_PATH}" -maxdepth 1 -name '*.tf' 2>/dev/null)" ]]; then
  error_exit "No Terraform files found in ${STACK_PATH}"
fi

# Backend config location
BACKEND_HCL="env/${ENV_NAME}/backend.hcl"
if [[ "${ENV_NAME}" == "global" ]]; then
  BACKEND_HCL="env/global/backend.hcl"
fi

if [[ ! -f "${BACKEND_HCL}" ]]; then
  error_exit "Backend config not found: ${BACKEND_HCL}. Run ./scripts/generate-backends.sh after bootstrap."
fi

# Validate backend.auto.tfvars.json exists for non-init actions
if [[ "${ACTION}" != "init" ]] && [[ "${ENV_NAME}" != "global" ]]; then
  AUTO_TFVARS="env/${ENV_NAME}/backend.auto.tfvars.json"
  if [[ ! -f "${AUTO_TFVARS}" ]]; then
    error_exit "Backend auto tfvars not found: ${AUTO_TFVARS}. Run ./scripts/generate-backends.sh"
  fi
fi

# State key convention
# - global stacks: global/<stack>.tfstate
# - env stacks: <env>/<category>/<stack>.tfstate
# Derive key from stack path
KEY=""
if [[ "${ENV_NAME}" == "global" ]]; then
  # stack-path like stacks/10-global/acr
  STACK_NAME=$(basename "${STACK_PATH}")
  KEY="global/${STACK_NAME}.tfstate"
else
  # stack-path like stacks/20-platform/core or stacks/30-apps/frontend
  CATEGORY=$(basename "$(dirname "${STACK_PATH}")")
  STACK_NAME=$(basename "${STACK_PATH}")
  if [[ "${CATEGORY}" == "20-platform" ]]; then
    KEY="${ENV_NAME}/platform/${STACK_NAME}.tfstate"
  elif [[ "${CATEGORY}" == "30-apps" ]]; then
    KEY="${ENV_NAME}/apps/${STACK_NAME}.tfstate"
  else
    # fallback
    KEY="${ENV_NAME}/${CATEGORY}/${STACK_NAME}.tfstate"
  fi
fi

pushd "${STACK_PATH}" >/dev/null

# Trap to ensure we popd on exit
trap 'popd >/dev/null' EXIT

info "Environment: ${ENV_NAME}"
info "Stack: ${STACK_PATH}"
info "State key: ${KEY}"

case "${ACTION}" in
  init)
    info "Initializing Terraform..."
    if ! terraform init -backend-config="../../${BACKEND_HCL}" -backend-config="key=${KEY}" "$@"; then
      error_exit "Terraform init failed"
    fi
    ;;
  plan)
    info "Initializing Terraform (if needed)..."
    terraform init -backend-config="../../${BACKEND_HCL}" -backend-config="key=${KEY}" -upgrade >/dev/null 2>&1 || true
    info "Running Terraform plan..."
    if ! terraform plan -var-file="../../env/${ENV_NAME}/backend.auto.tfvars.json" "$@"; then
      error_exit "Terraform plan failed"
    fi
    ;;
  apply)
    info "Initializing Terraform (if needed)..."
    terraform init -backend-config="../../${BACKEND_HCL}" -backend-config="key=${KEY}" -upgrade >/dev/null 2>&1 || true
    info "Running Terraform apply..."
    if ! terraform apply -var-file="../../env/${ENV_NAME}/backend.auto.tfvars.json" "$@"; then
      error_exit "Terraform apply failed"
    fi
    info "✅ Apply completed successfully"
    ;;
  destroy)
    info "⚠️  WARNING: This will destroy resources!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "${confirm}" != "yes" ]]; then
      info "Destroy cancelled"
      exit 0
    fi
    info "Initializing Terraform (if needed)..."
    terraform init -backend-config="../../${BACKEND_HCL}" -backend-config="key=${KEY}" -upgrade >/dev/null 2>&1 || true
    info "Running Terraform destroy..."
    if ! terraform destroy -var-file="../../env/${ENV_NAME}/backend.auto.tfvars.json" "$@"; then
      error_exit "Terraform destroy failed"
    fi
    ;;
  output)
    if ! terraform output "$@"; then
      error_exit "Failed to read Terraform outputs"
    fi
    ;;
  *)
    error_exit "Unknown action: ${ACTION}. Valid actions: init, plan, apply, destroy, output"
    ;;
esac

popd >/dev/null
trap - EXIT

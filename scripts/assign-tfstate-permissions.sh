#!/usr/bin/env bash
set -euo pipefail

# Script to assign Storage Blob Data Contributor role to a user for Terraform state access
#
# Usage:
#   ./scripts/assign-tfstate-permissions.sh --environment <env> [--user-id USER_ID] [--scope container|storage-account] [--dry-run]
#
# Options:
#   --environment ENV      Environment name (global, dev, stage, prod)
#   --user-id USER_ID      Azure AD user/principal ID (default: current logged-in user)
#   --scope SCOPE          Scope: 'container' (default) or 'storage-account' (all containers)
#   --dry-run              Print commands without executing them
#   --help                 Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

warning() {
  echo "⚠️  $1" >&2
}

# Check dependencies
if ! command -v az &> /dev/null; then
  error_exit "Azure CLI is not installed or not in PATH. Please install Azure CLI."
fi

if ! command -v terraform &> /dev/null; then
  error_exit "Terraform is not installed or not in PATH"
fi

if ! command -v jq &> /dev/null; then
  error_exit "jq is not installed. Please install jq to use this script."
fi

# Initialize variables
ENVIRONMENT=""
ALL_ENVIRONMENTS=false
USER_ID=""
SCOPE="container"
DRY_RUN=false

# Function to execute az commands or print them in dry-run mode
az_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "  🔍 [DRY-RUN] az $*" >&2
    return 0
  else
    az "$@"
  fi
}

# Function to ask for user confirmation
confirm_execution() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi
  
  echo ""
  warning "This will assign RBAC role 'Storage Blob Data Contributor':"
  
  if [[ "${ALL_ENVIRONMENTS}" == "true" ]]; then
    echo "  - For all environments: global, dev, stage, prod (4 containers)"
  else
    echo "  - For environment: ${ENVIRONMENT} (container: tfstate-${ENVIRONMENT})"
  fi
  
  if [[ "${SCOPE}" == "storage-account" ]]; then
    echo "  - Scope: Storage Account level (all containers)"
  else
    echo "  - Scope: Container level"
  fi
  
  echo "  - Assignee: ${USER_ID}"
  echo ""
  
  read -p "Do you want to continue? (yes/no): " -r
  echo ""
  
  if [[ ! "${REPLY}" =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Operation cancelled by user."
    exit 0
  fi
  
  echo ""
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --all-environments)
      ALL_ENVIRONMENTS=true
      shift
      ;;
    --user-id)
      USER_ID="$2"
      shift 2
      ;;
    --scope)
      SCOPE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      cat << EOF
Usage: $0 [OPTIONS]

Assign Storage Blob Data Contributor role to a user for Terraform state access.

Options:
  --environment ENV      Environment name (global, dev, stage, prod) [REQUIRED unless --all-environments]
  --all-environments     Assign role for all environments (global, dev, stage, prod)
  --user-id USER_ID      Azure AD user/principal ID (default: current logged-in user)
  --scope SCOPE          Scope: 'container' (default) or 'storage-account' (all containers)
  --dry-run              Print commands without executing them
  --help                 Show this help message

Examples:
  # Assign role to current user for global environment (container scope)
  $0 --environment global

  # Assign role for all environments (global, dev, stage, prod)
  $0 --all-environments

  # Assign role to specific user for dev environment
  $0 --environment dev --user-id "12345678-1234-1234-1234-123456789012"

  # Assign role at storage account level (all containers)
  $0 --environment global --scope storage-account

  # Dry run to see what would be executed
  $0 --all-environments --dry-run
EOF
      exit 0
      ;;
    *)
      error_exit "Unknown option: $1. Use --help for usage information."
      ;;
  esac
done

# Validate required arguments
if [[ "${ALL_ENVIRONMENTS}" == "false" ]] && [[ -z "${ENVIRONMENT}" ]]; then
  error_exit "--environment is required (or use --all-environments). Use --help for usage information."
fi

# Validate environment name (if not using --all-environments)
if [[ "${ALL_ENVIRONMENTS}" == "false" ]] && [[ ! "${ENVIRONMENT}" =~ ^(global|dev|stage|prod)$ ]]; then
  error_exit "Invalid environment: ${ENVIRONMENT}. Must be one of: global, dev, stage, prod"
fi

# Validate scope
if [[ ! "${SCOPE}" =~ ^(container|storage-account)$ ]]; then
  error_exit "Invalid scope: ${SCOPE}. Must be one of: container, storage-account"
fi

# Check if logged in (skip in dry-run mode)
if [[ "${DRY_RUN}" != "true" ]]; then
  if ! az account show &>/dev/null; then
    error_exit "Not logged in to Azure. Please run 'az login' first."
  fi
fi

# Get bootstrap stack outputs
BOOTSTRAP_DIR="${REPO_ROOT}/stacks/00-bootstrap/backend-local"

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

# Get user ID if not provided
if [[ -z "${USER_ID}" ]]; then
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "  🔍 [DRY-RUN] Would get current user ID"
    USER_ID="<current-user-id>"
  else
    info "Getting current user ID..."
    if ! USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null); then
      error_exit "Failed to get current user ID. Please ensure you are logged in with 'az login'."
    fi
    info "  Current user ID: ${USER_ID}"
  fi
else
  info "Using provided user ID: ${USER_ID}"
fi

# Ask for confirmation before executing (skip in dry-run mode)
confirm_execution

# Function to assign role for a specific environment
assign_role_for_environment() {
  local env="$1"
  
  info ""
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "Processing environment: ${env}"
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Determine scope ID
  local scope_id=""
  if [[ "${SCOPE}" == "container" ]]; then
    local container_name="tfstate-${env}"
    info "Container scope: ${container_name}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
      local storage_account_id="/subscriptions/<subscription-id>/resourceGroups/${TFSTATE_RG}/providers/Microsoft.Storage/storageAccounts/${TFSTATE_SA}"
      scope_id="${storage_account_id}/blobServices/default/containers/${container_name}"
    else
      # Get Storage Account ID
      local storage_account_id
      if ! storage_account_id=$(az storage account show \
        --name "${TFSTATE_SA}" \
        --resource-group "${TFSTATE_RG}" \
        --query id -o tsv 2>/dev/null); then
        error_exit "Failed to get Storage Account ID. Please check if Storage Account exists."
      fi
      
      scope_id="${storage_account_id}/blobServices/default/containers/${container_name}"
    fi
  else
    # Storage account scope
    info "Storage Account scope (all containers)"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
      scope_id="/subscriptions/<subscription-id>/resourceGroups/${TFSTATE_RG}/providers/Microsoft.Storage/storageAccounts/${TFSTATE_SA}"
    else
      # Get Storage Account ID
      if ! scope_id=$(az storage account show \
        --name "${TFSTATE_SA}" \
        --resource-group "${TFSTATE_RG}" \
        --query id -o tsv 2>/dev/null); then
        error_exit "Failed to get Storage Account ID. Please check if Storage Account exists."
      fi
    fi
  fi
  
  # Check if role assignment already exists
  info "Checking for existing role assignment..."
  
  local role_exists=false
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "  🔍 [DRY-RUN] Would check for existing role assignment"
    role_exists=false
  else
    local role_count
    if role_count=$(az role assignment list \
      --assignee "${USER_ID}" \
      --scope "${scope_id}" \
      --role "Storage Blob Data Contributor" \
      --query "length(@)" -o tsv 2>/dev/null); then
      
      if [[ "${role_count}" -gt 0 ]]; then
        role_exists=true
        warning "Role assignment already exists for user ${USER_ID} on scope ${scope_id}"
      fi
    fi
  fi
  
  # Assign role
  if [[ "${role_exists}" == "true" ]] && [[ "${DRY_RUN}" != "true" ]]; then
    info "Role assignment already exists. Skipping."
  else
    info "Assigning role 'Storage Blob Data Contributor'..."
    info "  Assignee: ${USER_ID}"
    info "  Scope: ${scope_id}"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
      az_cmd role assignment create \
        --role "Storage Blob Data Contributor" \
        --assignee "${USER_ID}" \
        --scope "${scope_id}"
      success "[DRY-RUN] Would assign role 'Storage Blob Data Contributor' for ${env}"
    else
      if az_cmd role assignment create \
        --role "Storage Blob Data Contributor" \
        --assignee "${USER_ID}" \
        --scope "${scope_id}" \
        --output none; then
        success "Role 'Storage Blob Data Contributor' assigned successfully for ${env}"
      else
        error_exit "Failed to assign role for ${env}. Please check your permissions."
      fi
    fi
  fi
  
  # Verify assignment
  if [[ "${DRY_RUN}" != "true" ]] && [[ "${role_exists}" != "true" ]]; then
    info "Verifying role assignment..."
    if az role assignment list \
      --assignee "${USER_ID}" \
      --scope "${scope_id}" \
      --role "Storage Blob Data Contributor" \
      --query "[].{Name:principalName, Role:roleDefinitionName, Scope:scope}" \
      --output table &>/dev/null; then
      success "Role assignment verified for ${env}"
    else
      warning "Could not verify role assignment for ${env}, but it may have been created successfully"
    fi
  fi
}

# Process environments
if [[ "${ALL_ENVIRONMENTS}" == "true" ]]; then
  info "Processing all environments: global, dev, stage, prod"
  ENVIRONMENTS=("global" "dev" "stage" "prod")
  
  for env in "${ENVIRONMENTS[@]}"; do
    assign_role_for_environment "${env}"
  done
  
  info ""
  success "Completed processing all environments"
else
  assign_role_for_environment "${ENVIRONMENT}"
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  info ""
  info "🔍 DRY-RUN mode: No changes were made. Remove --dry-run to execute."
fi

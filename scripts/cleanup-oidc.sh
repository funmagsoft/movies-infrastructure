#!/usr/bin/env bash
set -euo pipefail

# Script to cleanup Entra ID / OIDC resources created by setup-oidc.sh
# This script removes App Registrations / Service Principals and their
# Federated Identity Credentials (FIC) for GitHub OIDC authentication.
#
# Usage:
#   ./scripts/cleanup-oidc.sh [--remove-roles] [--subscription-id SUB_ID] [--dry-run]
#
# Options:
#   --remove-roles         Also remove RBAC role assignments (if they exist)
#   --subscription-id ID   Azure subscription ID (default: current subscription)
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

# Configuration
GITHUB_REPO="funmagsoft/movies-infrastructure"
ENVIRONMENTS=("global" "dev" "stage" "prod")
ORG="fms"
PROJECT="movies"

# Initialize variables
REMOVE_ROLES=false
SUBSCRIPTION_ID=""
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

dry_run() {
  echo "  🔍 [DRY-RUN] $1" >&2
}

# Function to ask for user confirmation
confirm_execution() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    return 0
  fi
  
  echo ""
  warning "This will DELETE Azure AD resources:"
  echo "  - App Registrations / Service Principals (4 total)"
  echo "  - Federated Identity Credentials (4 total)"
  if [[ "${REMOVE_ROLES}" == "true" ]]; then
    echo "  - RBAC role assignments (multiple per environment)"
  fi
  echo ""
  echo "Environments to process: ${ENVIRONMENTS[*]}"
  echo ""
  warning "⚠️  WARNING: This operation cannot be undone!"
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
    --remove-roles)
      REMOVE_ROLES=true
      shift
      ;;
    --subscription-id)
      SUBSCRIPTION_ID="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      cat << EOF
Usage: $0 [OPTIONS]

Cleanup Entra ID / OIDC resources created by setup-oidc.sh

Options:
  --remove-roles          Also remove RBAC role assignments (if they exist)
  --subscription-id ID    Azure subscription ID (default: current subscription)
  --dry-run               Print commands without executing them
  --help                  Show this help message

This script will:
1. Remove App Registrations / Service Principals for: global, dev, stage, prod
2. Remove Federated Identity Credentials (FIC) for GitHub OIDC
3. Optionally remove RBAC role assignments (if --remove-roles is used)

Service Principal naming convention:
  sp-tf-{env}-{org}-{project}

Example: sp-tf-dev-fms-movies

⚠️  WARNING: This operation cannot be undone!
EOF
      exit 0
      ;;
    *)
      error_exit "Unknown option: $1. Use --help for usage information."
      ;;
  esac
done

# Check if logged in (skip in dry-run mode)
if [[ "${DRY_RUN}" != "true" ]]; then
  if ! az account show &>/dev/null; then
    error_exit "Not logged in to Azure. Please run 'az login' first."
  fi
fi

# Set subscription if provided
if [[ -n "${SUBSCRIPTION_ID}" ]]; then
  info "Setting subscription to ${SUBSCRIPTION_ID}..."
  az_cmd account set --subscription "${SUBSCRIPTION_ID}" || error_exit "Failed to set subscription"
fi

# Get current subscription info
if [[ "${DRY_RUN}" == "true" ]]; then
  CURRENT_SUB="[DRY-RUN: subscription-id]"
  info "Using subscription: ${CURRENT_SUB} (dry-run mode)"
else
  CURRENT_SUB=$(az account show --query id -o tsv)
  info "Using subscription: ${CURRENT_SUB}"
fi

# Function to find and delete Service Principal
delete_sp() {
  local env=$1
  local sp_name="sp-tf-${env}-${ORG}-${PROJECT}"
  
  info "Processing Service Principal: ${sp_name}"
  
  # Find SP by display name to get app_id
  local app_id
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "  Checking if Service Principal exists..."
    dry_run "az ad sp list --display-name \"${sp_name}\" --query \"[0].appId\" -o tsv"
    info "  Would delete App Registration (this also deletes Service Principal)..."
    dry_run "az ad app delete --id \"<app-id>\""
    app_id="[DRY-RUN: app-id]"
  else
    # First try to find by Service Principal display name
    app_id=$(az ad sp list --display-name "${sp_name}" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    # If not found by SP, try to find by App Registration display name
    if [[ -z "${app_id}" ]] || [[ "${app_id}" == "null" ]]; then
      app_id=$(az ad app list --display-name "${sp_name}" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    fi
    
    if [[ -z "${app_id}" ]] || [[ "${app_id}" == "null" ]]; then
      info "  Service Principal/App Registration '${sp_name}' not found, skipping..."
      echo ""
      return
    fi
    
    info "  Found App Registration: ${app_id}"
    
    # Delete App Registration (this also deletes the Service Principal and FICs in home tenant)
    info "  Deleting App Registration (this also deletes Service Principal and FICs)..."
    
    # Try to delete
    local delete_output
    delete_output=$(az_cmd ad app delete --id "${app_id}" 2>&1)
    local delete_exit_code=$?
    
    # Wait a moment for deletion to propagate
    sleep 1
    
    # Verify deletion
    local still_exists
    still_exists=$(az ad app show --id "${app_id}" --query "appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${still_exists}" ]] || [[ "${still_exists}" == "null" ]]; then
      success "  App Registration, Service Principal, and FICs deleted"
    elif [[ "${delete_exit_code}" -eq 0 ]]; then
      # Command succeeded but app still exists - might be a timing issue
      info "  Deletion initiated, verifying..."
      sleep 2
      still_exists=$(az ad app show --id "${app_id}" --query "appId" -o tsv 2>/dev/null || echo "")
      if [[ -z "${still_exists}" ]] || [[ "${still_exists}" == "null" ]]; then
        success "  App Registration, Service Principal, and FICs deleted"
      else
        warning "  App Registration may still exist. Please verify manually:"
        warning "    az ad app show --id ${app_id}"
        warning "    az ad app delete --id ${app_id}"
      fi
    else
      # Command failed
      if [[ -n "${delete_output}" ]]; then
        warning "  Error output: ${delete_output}"
      fi
      warning "  Failed to delete App Registration. Please try manually:"
      warning "    az ad app delete --id ${app_id}"
    fi
  fi
  
  echo "${app_id}"
}

# Function to remove RBAC role assignments
remove_rbac_roles() {
  local app_id=$1
  local env=$2
  local sp_name="sp-tf-${env}-${ORG}-${PROJECT}"
  
  if [[ "${app_id}" == "" ]] || [[ "${app_id}" == "[DRY-RUN: app-id]" ]]; then
    warning "    Cannot remove roles: App ID not available"
    return
  fi
  
  info "  Removing RBAC role assignments for ${sp_name}..."
  
  # Get subscription ID
  local sub_id
  if [[ "${DRY_RUN}" == "true" ]]; then
    sub_id="[DRY-RUN: subscription-id]"
  else
    sub_id=$(az account show --query id -o tsv)
  fi
  
  # For global environment
  if [[ "${env}" == "global" ]]; then
    warning "    Global SP roles should be removed manually from global resources"
    return
  fi
  
  # Read bootstrap outputs to get tfstate RG and SA
  local bootstrap_dir="${REPO_ROOT}/stacks/00-bootstrap/backend-local"
  if [[ ! -d "${bootstrap_dir}" ]]; then
    warning "    Bootstrap stack not found. Cannot determine role assignments to remove."
    warning "    Remove roles manually using:"
    warning "      az role assignment list --assignee ${app_id} --all"
    return
  fi
  
  # Try to read bootstrap outputs
  local tfstate_rg tfstate_sa
  if command -v terraform &>/dev/null && command -v jq &>/dev/null; then
    pushd "${bootstrap_dir}" >/dev/null
    if terraform init >/dev/null 2>&1 && terraform output -json >/dev/null 2>&1; then
      local out_json
      out_json=$(terraform output -json 2>/dev/null || echo "{}")
      tfstate_rg=$(echo "${out_json}" | jq -r '.tfstate_resource_group_name.value // empty' 2>/dev/null || echo "")
      tfstate_sa=$(echo "${out_json}" | jq -r '.tfstate_storage_account_name.value // empty' 2>/dev/null || echo "")
    fi
    popd >/dev/null
  fi
  
  if [[ -z "${tfstate_rg}" ]] || [[ -z "${tfstate_sa}" ]]; then
    warning "    Bootstrap outputs not available. Cannot determine role assignments."
    warning "    List and remove roles manually using:"
    warning "      az role assignment list --assignee ${app_id} --all"
    return
  fi
  
  # Construct resource names
  local env_rg="rg-${ORG}-${PROJECT}-${env}-plc-01"
  
  # List all role assignments for this SP
  info "    Finding role assignments for ${sp_name}..."
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    dry_run "az role assignment list --assignee \"${app_id}\" --all --query \"[].{role:roleDefinitionName,scope:scope}\" -o table"
    info "    Would remove all role assignments..."
  else
    # Check if jq is available for JSON parsing
    if ! command -v jq &>/dev/null; then
      warning "    jq is not installed. Cannot parse role assignments automatically."
      warning "    Remove role assignments manually using:"
      warning "      az role assignment list --assignee ${app_id} --all"
      return
    fi
    
    # Get all role assignments for this SP
    local role_assignments_json
    role_assignments_json=$(az role assignment list --assignee "${app_id}" --all -o json 2>/dev/null || echo "[]")
    
    local assignment_count
    assignment_count=$(echo "${role_assignments_json}" | jq -r 'length' 2>/dev/null || echo "0")
    
    if [[ "${assignment_count}" == "0" ]] || [[ -z "${role_assignments_json}" ]] || [[ "${role_assignments_json}" == "[]" ]]; then
      info "    No role assignments found"
      return
    fi
    
    info "    Found ${assignment_count} role assignment(s)"
    
    # Remove each role assignment by ID
    echo "${role_assignments_json}" | jq -r '.[] | "\(.id)|\(.scope)|\(.roleDefinitionName)"' 2>/dev/null | while IFS='|' read -r assignment_id scope role_name; do
      if [[ -n "${assignment_id}" ]]; then
        info "    Removing role assignment: ${role_name} at ${scope}"
        if az_cmd role assignment delete --ids "${assignment_id}" >/dev/null 2>&1; then
          success "      Role assignment removed"
        else
          warning "      Failed to remove role assignment (may already be removed)"
        fi
      fi
    done
  fi
}

# Main execution
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "🗑️  GitHub Actions OIDC Cleanup (DRY-RUN MODE)"
else
  echo "🗑️  GitHub Actions OIDC Cleanup"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
  warning "DRY-RUN MODE: Commands will be printed but not executed"
  echo ""
fi
info "Repository: ${GITHUB_REPO}"
info "Environments: ${ENVIRONMENTS[*]}"
echo ""

# Ask for confirmation before executing (skip in dry-run mode)
confirm_execution

# Process each environment
declare -A SP_APP_IDS

for env in "${ENVIRONMENTS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "Processing environment: ${env}"
  echo ""
  
  # Delete SP (this also deletes App Registration and FICs)
  app_id=$(delete_sp "${env}")
  SP_APP_IDS["${env}"]="${app_id}"
  
  # Remove RBAC roles if requested
  if [[ "${REMOVE_ROLES}" == "true" ]] && [[ "${app_id}" != "" ]]; then
    echo ""
    remove_rbac_roles "${app_id}" "${env}"
  fi
  
  echo ""
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for env in "${ENVIRONMENTS[@]}"; do
  sp_name="sp-tf-${env}-${ORG}-${PROJECT}"
  echo "  ${sp_name}:"
  if [[ "${SP_APP_IDS[${env}]}" != "" ]] && [[ "${SP_APP_IDS[${env}]}" != "[DRY-RUN: app-id]" ]]; then
    echo "    Status: Deleted"
    echo "    App ID: ${SP_APP_IDS[${env}]}"
  elif [[ "${SP_APP_IDS[${env}]}" == "[DRY-RUN: app-id]" ]]; then
    echo "    Status: Would be deleted (dry-run)"
  else
    echo "    Status: Not found (already deleted or never existed)"
  fi
  echo ""
done

if [[ "${REMOVE_ROLES}" != "true" ]]; then
  echo ""
  warning "RBAC role assignments were not removed. To remove roles, run:"
  echo "  $0 --remove-roles"
  echo ""
  warning "Or remove roles manually using the App IDs above."
fi

echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
  warning "DRY-RUN completed! No changes were made."
  echo ""
  info "To execute these commands, run without --dry-run:"
  echo "  $0${REMOVE_ROLES:+ --remove-roles}${SUBSCRIPTION_ID:+ --subscription-id ${SUBSCRIPTION_ID}}"
else
  success "Cleanup completed!"
fi
echo ""
info "Note: If Service Principals were not found, they may have been:"
echo "  - Already deleted"
echo "  - Never created"
echo "  - Created with different names"
echo ""

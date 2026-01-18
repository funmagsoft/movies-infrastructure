#!/usr/bin/env bash
set -euo pipefail

# Script to setup Entra ID / OIDC for GitHub Actions
# This script creates App Registrations / Service Principals and configures
# Federated Identity Credentials (FIC) for GitHub OIDC authentication.
#
# Usage:
#   ./scripts/setup-oidc.sh [--assign-roles] [--subscription-id SUB_ID] [--dry-run]
#
# Options:
#   --assign-roles          Also assign RBAC roles (requires RG and Storage Account to exist)
#   --subscription-id ID    Azure subscription ID (default: current subscription)
#   --dry-run               Print commands without executing them
#   --help                  Show this help message

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

# Check if logged in (skip in dry-run mode)
# Note: DRY_RUN is checked after parsing arguments, but we need to check login before that
# So we'll check login conditionally after parsing

# Configuration
GITHUB_REPO="funmagsoft/movies-infrastructure"
ENVIRONMENTS=("global" "dev" "stage" "prod")
ORG="fms"
PROJECT="movies"

# Initialize variables
ASSIGN_ROLES=false
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
  warning "This will create/modify Azure AD resources:"
  echo "  - App Registrations / Service Principals (4 total)"
  echo "  - Federated Identity Credentials (4 total)"
  if [[ "${ASSIGN_ROLES}" == "true" ]]; then
    echo "  - RBAC role assignments (multiple per environment)"
  fi
  echo ""
  echo "Environments to process: ${ENVIRONMENTS[*]}"
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
    --assign-roles)
      ASSIGN_ROLES=true
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

Setup Entra ID / OIDC for GitHub Actions

Options:
  --assign-roles          Also assign RBAC roles (requires RG and Storage Account to exist)
  --subscription-id ID    Azure subscription ID (default: current subscription)
  --dry-run               Print commands without executing them
  --help                  Show this help message

This script will:
1. Create App Registrations / Service Principals for: global, dev, stage, prod
2. Configure Federated Identity Credentials (FIC) for GitHub OIDC
3. Optionally assign RBAC roles (if --assign-roles is used)

Service Principal naming convention:
  sp-tf-{env}-{org}-{project}

Example: sp-tf-dev-fms-movies

Federated Identity Credentials:
  Subject: repo:${GITHUB_REPO}:environment:{env}
  Repository: ${GITHUB_REPO}
  Environment: {env} (dev, stage, prod, global)
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

# Function to create or get Service Principal
create_or_get_sp() {
  local env=$1
  local sp_name="sp-tf-${env}-${ORG}-${PROJECT}"
  
  info "Processing Service Principal: ${sp_name}"
  
  # Check if SP already exists
  local app_id
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "  Checking if Service Principal exists..."
    dry_run "az ad sp list --display-name \"${sp_name}\" --query \"[0].appId\" -o tsv"
    info "  Would create App Registration if not exists..."
    dry_run "az ad app create --display-name \"${sp_name}\" --query appId -o tsv"
    dry_run "az ad sp create --id \"<app-id>\""
    info "  Service Principal would be created or found"
    app_id="[DRY-RUN: app-id]"
  else
    app_id=$(az ad sp list --display-name "${sp_name}" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${app_id}" ]] || [[ "${app_id}" == "null" ]]; then
      info "  Creating App Registration..."
      
      # Create App Registration
      app_id=$(az_cmd ad app create \
        --display-name "${sp_name}" \
        --query appId -o tsv) || error_exit "Failed to create App Registration"
      
      success "  App Registration created: ${app_id}"
      
      # Create Service Principal
      az_cmd ad sp create --id "${app_id}" >/dev/null || error_exit "Failed to create Service Principal"
      success "  Service Principal created"
    else
      info "  Service Principal already exists: ${app_id}"
    fi
  fi
  
  echo "${app_id}"
}

# Function to create or update Federated Identity Credential
create_or_update_fic() {
  local app_id=$1
  local env=$2
  local sp_name="sp-tf-${env}-${ORG}-${PROJECT}"
  
  info "  Configuring Federated Identity Credential for environment: ${env}"
  
  local subject="repo:${GITHUB_REPO}:environment:${env}"
  local fic_name="github-actions-${env}"
  
  # Check if FIC already exists
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "    Checking if FIC '${fic_name}' exists..."
    dry_run "az ad app federated-credential list --id \"<app-id>\" --query \"[?name=='${fic_name}'].name\" -o tsv"
    info "    Would create or update FIC..."
    local fic_params="{\"name\":\"${fic_name}\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"${subject}\",\"audiences\":[\"api://AzureADTokenExchange\"],\"description\":\"GitHub Actions OIDC for ${env} environment\"}"
    dry_run "az ad app federated-credential create --id \"<app-id>\" --parameters '${fic_params}'"
    info "    FIC would be created or updated"
  else
    local existing_fic
    existing_fic=$(az ad app federated-credential list \
      --id "${app_id}" \
      --query "[?name=='${fic_name}'].name" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "${existing_fic}" ]]; then
      info "    FIC '${fic_name}' already exists, updating..."
      
      az_cmd ad app federated-credential update \
        --id "${app_id}" \
        --federated-credential-id "${fic_name}" \
        --parameters "{
          \"name\": \"${fic_name}\",
          \"issuer\": \"https://token.actions.githubusercontent.com\",
          \"subject\": \"${subject}\",
          \"audiences\": [\"api://AzureADTokenExchange\"],
          \"description\": \"GitHub Actions OIDC for ${env} environment\"
        }" >/dev/null || error_exit "Failed to update FIC"
      
      success "    FIC updated"
    else
      info "    Creating FIC '${fic_name}'..."
      
      az_cmd ad app federated-credential create \
        --id "${app_id}" \
        --parameters "{
          \"name\": \"${fic_name}\",
          \"issuer\": \"https://token.actions.githubusercontent.com\",
          \"subject\": \"${subject}\",
          \"audiences\": [\"api://AzureADTokenExchange\"],
          \"description\": \"GitHub Actions OIDC for ${env} environment\"
        }" >/dev/null || error_exit "Failed to create FIC"
      
      success "    FIC created"
    fi
  fi
  
  info "    Subject: ${subject}"
}

# Function to assign RBAC roles
assign_rbac_roles() {
  local app_id=$1
  local env=$2
  local sp_name="sp-tf-${env}-${ORG}-${PROJECT}"
  
  info "  Assigning RBAC roles for ${sp_name}..."
  
  # Get subscription ID
  local sub_id
  if [[ "${DRY_RUN}" == "true" ]]; then
    sub_id="[DRY-RUN: subscription-id]"
  else
    sub_id=$(az account show --query id -o tsv)
  fi
  
  # For global environment
  if [[ "${env}" == "global" ]]; then
    warning "    Global SP roles should be assigned manually to global resources"
    return
  fi
  
  # Read bootstrap outputs to get tfstate RG and SA
  local bootstrap_dir="${REPO_ROOT}/stacks/00-bootstrap/backend-local"
  if [[ ! -d "${bootstrap_dir}" ]]; then
    warning "    Bootstrap stack not found. Skipping RBAC role assignments."
    warning "    You can assign roles manually later using:"
    warning "      az role assignment create --assignee ${app_id} --role <ROLE> --scope <SCOPE>"
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
    warning "    Bootstrap outputs not available. Skipping automatic RBAC assignments."
    warning "    You need to assign roles manually:"
    warning "      1. Owner on environment RG: rg-${ORG}-${PROJECT}-${env}-plc-01"
    warning "      2. Storage Blob Data Contributor on tfstate container: tfstate-${env}"
    warning "      3. Reader on tfstate RG: ${tfstate_rg}"
    if [[ "${env}" != "global" ]]; then
      warning "      4. Reader on tfstate-global container (for ACR access)"
    fi
    return
  fi
  
  # Construct resource names (following naming convention from README)
  local env_rg="rg-${ORG}-${PROJECT}-${env}-plc-01"
  
  # Check if environment RG exists
  if [[ "${DRY_RUN}" == "true" ]]; then
    info "    Would check if environment RG '${env_rg}' exists..."
    dry_run "az group show --name \"${env_rg}\""
    info "    Would assign Owner role on ${env_rg}..."
    dry_run "az role assignment create --assignee \"${app_id}\" --role \"Owner\" --scope \"/subscriptions/${sub_id}/resourceGroups/${env_rg}\""
  else
    if ! az group show --name "${env_rg}" &>/dev/null; then
      warning "    Environment RG '${env_rg}' does not exist yet. Skipping role assignment."
      warning "    Assign Owner role manually after creating the RG."
    else
      info "    Assigning Owner role on ${env_rg}..."
      az_cmd role assignment create \
        --assignee "${app_id}" \
        --role "Owner" \
        --scope "/subscriptions/${sub_id}/resourceGroups/${env_rg}" \
        >/dev/null 2>&1 && success "      Owner role assigned" || warning "      Role may already exist"
    fi
  fi
  
  # Assign Storage Blob Data Contributor on tfstate container
  info "    Assigning Storage Blob Data Contributor on tfstate container..."
  local container_scope="/subscriptions/${sub_id}/resourceGroups/${tfstate_rg}/providers/Microsoft.Storage/storageAccounts/${tfstate_sa}/blobServices/default/containers/tfstate-${env}"
  
  if [[ "${DRY_RUN}" == "true" ]]; then
    dry_run "az role assignment create --assignee \"${app_id}\" --role \"Storage Blob Data Contributor\" --scope \"${container_scope}\""
  else
    az_cmd role assignment create \
      --assignee "${app_id}" \
      --role "Storage Blob Data Contributor" \
      --scope "${container_scope}" \
      >/dev/null 2>&1 && success "      Storage Blob Data Contributor assigned" || warning "      Role may already exist"
  fi
  
  # Assign Reader on tfstate RG
  info "    Assigning Reader role on tfstate RG..."
  if [[ "${DRY_RUN}" == "true" ]]; then
    dry_run "az role assignment create --assignee \"${app_id}\" --role \"Reader\" --scope \"/subscriptions/${sub_id}/resourceGroups/${tfstate_rg}\""
  else
    az_cmd role assignment create \
      --assignee "${app_id}" \
      --role "Reader" \
      --scope "/subscriptions/${sub_id}/resourceGroups/${tfstate_rg}" \
      >/dev/null 2>&1 && success "      Reader role assigned" || warning "      Role may already exist"
  fi
  
  # For non-global envs, assign Reader on tfstate-global container
  if [[ "${env}" != "global" ]]; then
    info "    Assigning Reader role on tfstate-global container (for ACR access)..."
    local global_container_scope="/subscriptions/${sub_id}/resourceGroups/${tfstate_rg}/providers/Microsoft.Storage/storageAccounts/${tfstate_sa}/blobServices/default/containers/tfstate-global"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
      dry_run "az role assignment create --assignee \"${app_id}\" --role \"Storage Blob Data Contributor\" --scope \"${global_container_scope}\""
    else
      az_cmd role assignment create \
        --assignee "${app_id}" \
        --role "Storage Blob Data Contributor" \
        --scope "${global_container_scope}" \
        >/dev/null 2>&1 && success "      Reader access to tfstate-global assigned" || warning "      Role may already exist"
    fi
  fi
}

# Main execution
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "${DRY_RUN}" == "true" ]]; then
  echo "🔐 GitHub Actions OIDC Setup (DRY-RUN MODE)"
else
  echo "🔐 GitHub Actions OIDC Setup"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
  warning "DRY-RUN MODE: Commands will be printed but not executed"
  echo ""
fi
info "Repository: ${GITHUB_REPO}"
info "Environments: ${ENVIRONMENTS[*]}"

# Ask for confirmation before executing (skip in dry-run mode)
confirm_execution

# Process each environment
declare -A SP_APP_IDS

for env in "${ENVIRONMENTS[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "Processing environment: ${env}"
  echo ""
  
  # Create or get SP
  app_id=$(create_or_get_sp "${env}")
  SP_APP_IDS["${env}"]="${app_id}"
  
  # Create or update FIC
  create_or_update_fic "${app_id}" "${env}"
  
  # Assign RBAC roles if requested
  if [[ "${ASSIGN_ROLES}" == "true" ]]; then
    echo ""
    assign_rbac_roles "${app_id}" "${env}"
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
  echo "    App ID: ${SP_APP_IDS[${env}]}"
  echo "    FIC Subject: repo:${GITHUB_REPO}:environment:${env}"
  echo ""
done

if [[ "${ASSIGN_ROLES}" != "true" ]]; then
  echo ""
  warning "RBAC roles were not assigned. To assign roles, run:"
  echo "  $0 --assign-roles"
  echo ""
  warning "Or assign roles manually using the App IDs above."
fi

echo ""
if [[ "${DRY_RUN}" == "true" ]]; then
  warning "DRY-RUN completed! No changes were made."
  echo ""
  info "To execute these commands, run without --dry-run:"
  echo "  $0${ASSIGN_ROLES:+ --assign-roles}${SUBSCRIPTION_ID:+ --subscription-id ${SUBSCRIPTION_ID}}"
else
  success "Setup completed!"
fi
echo ""
info "Next steps:"
echo "  1. Configure GitHub Environments (dev, stage, prod, global) in repository settings"
echo "  2. Enable branch protection on main branch"
echo "  3. (Optional) Enable approvals for prod environment"
echo "  4. If roles were not assigned, assign them manually or run with --assign-roles"
echo ""

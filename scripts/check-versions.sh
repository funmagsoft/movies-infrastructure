#!/usr/bin/env bash
set -euo pipefail

# Script to check that all versions.tf files match the central terraform-versions-reference.tf
# This ensures consistency across all modules and stacks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

# Extract versions from central reference file
VERSIONS_REF="${SCRIPT_DIR}/terraform-versions-reference.tf"
REQUIRED_TERRAFORM_VERSION=$(grep -A 1 'required_version' "${VERSIONS_REF}" | grep -oP '(?<=").*(?=")' | head -1)
REQUIRED_AZURERM_VERSION=$(grep -A 2 'azurerm' "${VERSIONS_REF}" | grep 'version' | grep -oP '(?<=").*(?=")')

echo "📋 Central versions:"
echo "  Terraform: ${REQUIRED_TERRAFORM_VERSION}"
echo "  azurerm:   ${REQUIRED_AZURERM_VERSION}"
echo ""

FAILED=0
PASSED=0

# Check all versions.tf files
for versions_file in modules/*/versions.tf stacks/*/*/versions.tf; do
  if [ ! -f "${versions_file}" ]; then
    continue
  fi

  file_terraform_version=$(grep -A 1 'required_version' "${versions_file}" 2>/dev/null | grep -oP '(?<=").*(?=")' | head -1 || echo "")
  file_azurerm_version=$(grep -A 2 'azurerm' "${versions_file}" 2>/dev/null | grep 'version' | grep -oP '(?<=").*(?=")' || echo "")

  if [ "${file_terraform_version}" != "${REQUIRED_TERRAFORM_VERSION}" ] || [ "${file_azurerm_version}" != "${REQUIRED_AZURERM_VERSION}" ]; then
    echo "❌ ${versions_file}"
    echo "   Terraform: expected '${REQUIRED_TERRAFORM_VERSION}', got '${file_terraform_version}'"
    echo "   azurerm:   expected '${REQUIRED_AZURERM_VERSION}', got '${file_azurerm_version}'"
    ((FAILED++))
  else
    echo "✅ ${versions_file}"
    ((PASSED++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${FAILED} -gt 0 ]; then
  echo ""
  echo "💡 Tip: Run scripts/sync-versions.sh to automatically sync all versions.tf files"
  exit 1
fi

exit 0

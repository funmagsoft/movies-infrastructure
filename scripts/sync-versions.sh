#!/usr/bin/env bash
set -euo pipefail

# Script to sync all versions.tf files with the central terraform-versions-reference.tf
# This ensures all modules and stacks use the same Terraform and provider versions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

# Read the central versions reference file content
VERSIONS_REF="${SCRIPT_DIR}/terraform-versions-reference.tf"
VERSIONS_CONTENT=$(cat "${VERSIONS_REF}" | sed 's/# Central Terraform version configuration/# Terraform version requirements/' | sed '/# Note:/,$d')

echo "🔄 Syncing versions.tf files with central configuration..."
echo ""

SYNCED=0
SKIPPED=0

# Update all versions.tf files
for versions_file in modules/*/versions.tf stacks/*/*/versions.tf; do
  if [ ! -f "${versions_file}" ]; then
    continue
  fi

  # Check if file needs updating
  if diff -q <(echo "${VERSIONS_CONTENT}") "${versions_file}" > /dev/null 2>&1; then
    echo "✓ ${versions_file} - already in sync"
    ((SKIPPED++))
  else
    echo "${VERSIONS_CONTENT}" > "${versions_file}"
    echo "✏️  ${versions_file} - updated"
    ((SYNCED++))
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Synced: ${SYNCED} files, Skipped: ${SKIPPED} files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${SYNCED} -gt 0 ]; then
  echo ""
  echo "✅ All versions.tf files are now in sync!"
  echo "💡 Run 'scripts/check-versions.sh' to verify"
fi

#!/usr/bin/env bash
set -euo pipefail

# Basic validation tests for Terraform modules
# This script validates that all modules can be initialized and validated

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

echo "🔍 Running Terraform module validation tests..."

FAILED=0
PASSED=0

# Test all modules
# Find all module directories by looking for main.tf or versions.tf files
# This includes modules/azure/*/ and modules/standards/
mapfile -t module_dirs < <(find modules -name "main.tf" -o -name "versions.tf" 2>/dev/null | sed 's|/[^/]*$||' | sort -u)

for module_dir in "${module_dirs[@]}"; do
  # Get relative path from modules/ for display
  module_path="${module_dir#modules/}"
  echo ""
  echo "📦 Testing module: ${module_path}"
  
  # Check if there are any .tf files
  if ! ls "${module_dir}"/*.tf > /dev/null 2>&1; then
    echo "  ⚠️  Skipping ${module_path} - no .tf files found"
    continue
  fi

  cd "${module_dir}"
  
  if terraform init -backend=false > /dev/null 2>&1; then
    if terraform validate > /dev/null 2>&1; then
      echo "  ✅ ${module_path} - validation passed"
      ((PASSED++)) || true
    else
      echo "  ❌ ${module_path} - validation failed"
      terraform validate
      ((FAILED++)) || true
    fi
  else
    echo "  ❌ ${module_path} - init failed"
    terraform init -backend=false
    ((FAILED++)) || true
  fi
  
  cd "${REPO_ROOT}"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${FAILED} -gt 0 ]; then
  exit 1
fi

exit 0

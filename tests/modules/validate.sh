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
for module_dir in modules/*/; do
  module_name=$(basename "${module_dir}")
  echo ""
  echo "📦 Testing module: ${module_name}"
  
  if [ ! -f "${module_dir}main.tf" ] && [ ! -f "${module_dir}*.tf" ]; then
    echo "  ⚠️  Skipping ${module_name} - no .tf files found"
    continue
  fi

  cd "${module_dir}"
  
  if terraform init -backend=false > /dev/null 2>&1; then
    if terraform validate > /dev/null 2>&1; then
      echo "  ✅ ${module_name} - validation passed"
      ((PASSED++))
    else
      echo "  ❌ ${module_name} - validation failed"
      terraform validate
      ((FAILED++))
    fi
  else
    echo "  ❌ ${module_name} - init failed"
    terraform init -backend=false
    ((FAILED++))
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

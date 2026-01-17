# Central Terraform version configuration
# This file serves as a reference for required Terraform and provider versions
# All modules and stacks should use the same versions defined here
# 
# This file is used by scripts/check-versions.sh and scripts/sync-versions.sh
# to ensure version consistency across all modules and stacks.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.50.0, < 5.0.0"
    }
  }
}

# Note: This file is for reference only. Each module and stack must have its own versions.tf
# Use scripts/check-versions.sh to ensure all versions.tf files are in sync
# Use scripts/sync-versions.sh to automatically sync all versions.tf files

provider "azurerm" {
  features {}
  # subscription_id can be set via:
  # 1. Environment variable: ARM_SUBSCRIPTION_ID (automatically read by provider) - RECOMMENDED
  # 2. Variable: -var="subscription_id=..." or TF_VAR_subscription_id=...
  # Note: Azure CLI default subscription (az account set) does NOT work reliably with AzureRM provider v4.50.0+
  subscription_id = var.subscription_id != null && var.subscription_id != "" ? var.subscription_id : null
}

data "azurerm_client_config" "current" {}

data "azurerm_client_config" "current" {}

locals {
  env_short_map = {
    dev   = "d"
    stage = "s"
    prod  = "p"
    shared = "x"
    global = "x"
  }

  env_short = try(local.env_short_map[var.environment], substr(var.environment, 0, 1))

  # Stable suffix to avoid global name collisions for constrained resources.
  sub_hash = substr(md5(data.azurerm_client_config.current.subscription_id), 0, 4)

  name_suffix       = "${var.org}-${var.project}-${var.environment}-${var.region_short}-${var.instance}"
  constrained_suffix = lower("${var.org}${var.project_short}${local.env_short}${var.region_short}${local.sub_hash}${var.instance}")

  required_tags = {
    org         = var.org
    project     = var.project
    environment = var.environment
    region      = var.region
    managedBy   = "terraform"
    repo        = "movies-infrastructure"
    stack       = var.stack
    owner       = var.owner
    costCenter  = var.cost_center
  }

  tags = merge(local.required_tags, var.extra_tags)
}

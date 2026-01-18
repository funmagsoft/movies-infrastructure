resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.dns_prefix

  kubernetes_version = var.kubernetes_version

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                 = "system"
    vm_size              = var.system_node_vm_size
    vnet_subnet_id       = var.subnet_id
    auto_scaling_enabled = true
    min_count            = var.system_node_min
    max_count            = var.system_node_max
    os_disk_size_gb      = 30
    type                 = "VirtualMachineScaleSets"
    orchestrator_version = var.kubernetes_version

    # Configure upgrade settings to avoid surge nodes when vCPU quota is limited
    # max_surge = "0" means no additional nodes during upgrade (uses max_unavailable instead)
    upgrade_settings {
      max_surge = var.node_pool_max_surge
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_aad_rbac ? [1] : []
    content {
      azure_rbac_enabled     = true
      admin_group_object_ids = var.aad_admin_group_object_ids
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags,
      default_node_pool[0].orchestrator_version,
      kubernetes_version
    ]
  }
}

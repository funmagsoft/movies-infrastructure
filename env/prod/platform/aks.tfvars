environment         = "prod"
# API server allow-list
authorized_ip_ranges = ["91.150.222.105/32"]

# Cheapest sensible defaults
system_node_min = 2
system_node_max = 3

# Shared ACR lookup (created by global stack)
acr_resource_group_name = "rg-fms-movies-shared-plc-01"
# Acr name is deterministic (constrained). If you changed org/project_short/instance, update here.
acr_name = "acrfmsmovxplc"  # Placeholder; will be corrected by README guidance

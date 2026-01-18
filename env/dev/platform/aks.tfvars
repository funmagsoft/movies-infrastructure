environment = "dev"
# API server allow-list
# Add your current IP to access AKS API server
# Get your IP: curl -s ifconfig.me
authorized_ip_ranges = ["91.150.222.105/32", "89.73.196.202/32"]

# Using Standard_D2s_v3 (2 vCPU, 8GB RAM) - available in polandcentral
system_node_vm_size = "Standard_D2s_v3"
system_node_min     = 1
system_node_max     = 2

# ACR is now automatically discovered from global stack remote state

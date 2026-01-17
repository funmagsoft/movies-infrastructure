environment    = "prod"
address_space  = ["10.62.0.0/16"]
subnet_prefixes = {
  aks_nodes         = ["10.62.0.0.0/20"]
  private_endpoints = ["10.62.0.20.0/24"]
}

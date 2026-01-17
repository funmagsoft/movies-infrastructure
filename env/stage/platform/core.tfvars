environment    = "stage"
address_space  = ["10.61.0.0/16"]
subnet_prefixes = {
  aks_nodes         = ["10.61.0.0.0/20"]
  private_endpoints = ["10.61.0.20.0/24"]
}

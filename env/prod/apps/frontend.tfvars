environment             = "prod"
k8s_namespace           = "movies-frontend"
k8s_service_account_name = "frontend"

# Initially false; enable later when platform/data is on
needs_keyvault   = false
needs_servicebus = false
needs_storage    = false

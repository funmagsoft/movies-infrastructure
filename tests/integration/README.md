# Integration Tests

This directory contains integration tests for Terraform stacks.

## Prerequisites

- Terraform >= 1.6.0
- Azure CLI configured
- Appropriate Azure permissions

## Running Tests

Integration tests use `terratest` framework. To run:

```bash
cd tests/integration
go test -v -timeout 30m
```

## Test Structure

- Each test file corresponds to a stack or module
- Tests verify that resources are created correctly
- Tests clean up resources after completion

## Future Tests

- AKS cluster creation and configuration
- Network setup and connectivity
- Key Vault access policies
- Storage account configuration
- Identity and RBAC assignments

# Terraform

Provider-native modules. No cross-cloud VPC module.

`make validate` runs `terraform init -backend=false` and `validate`.
Remote state, locking and encryption are mandatory in a real estate
and intentionally absent here so the reference can be checked in CI.

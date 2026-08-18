# Azure Terraform skeleton

Hub-and-spoke VNets in one resource group so this reference can validate
without a management group hierarchy. Real estates put connectivity and
workloads in separate subscriptions. See `landing-zones/azure` and
`docs/architecture/azure.md`.

AKS, Key Vault, ACR and Azure Firewall are intentionally not in this
composition yet. Adding them before the identity and DNS design is how
you get a cluster that cannot pull images.

Virtual WAN is documented as the scale-up path, not the default.

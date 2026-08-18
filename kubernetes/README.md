# Kubernetes overlays

`base` is the contract. Overlays only change workload identity
annotations and, later, storage classes. They do not fork the
Deployment.

On EKS the golden path is Pod Identity, configured in Terraform, so the
EKS overlay does not add an IRSA annotation. `irsa-patch.yaml` is the
escape hatch.

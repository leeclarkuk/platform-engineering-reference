# Kubernetes overlays

`base` is the contract. Overlays only change workload identity annotations
and, later, storage classes. They do not fork the Deployment.

Account IDs in overlays are placeholders. Replace them per environment in
GitOps, not by copying this tree three times.

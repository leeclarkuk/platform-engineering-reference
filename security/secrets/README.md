# Secrets

System of record: Secrets Manager, Key Vault, Secret Manager.
Kubernetes: External Secrets Operator. Git: no production secrets.

Rotation is a per-cloud native feature plus an application restart
(or file watch). If a service cannot survive rotation, that is a
readiness defect.

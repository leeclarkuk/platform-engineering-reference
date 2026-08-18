# ADR-006: Secrets management

- Status: Accepted
- Date: 2026-08-18

## Context

Workloads need secrets. Humans need break-glass. CI needs to not hold
production database passwords. Each cloud already has a native secret store.

## Options considered

1. **Cloud-native stores plus External Secrets Operator.** AWS Secrets
   Manager / SSM, Azure Key Vault, GCP Secret Manager. ESO syncs into
   Kubernetes as needed.
2. **HashiCorp Vault as the enterprise secret plane.** Strong for
   multi-cloud and dynamic credentials. Another control plane to run.
3. **Sealed Secrets / SOPS in Git.** Fine for non-rotating config. Poor for
   production credentials that must rotate and be revoked.
4. **Kubernetes Secrets only.** Encrypt at rest if you remember to, no
   rotation story, no IAM audit trail worth the name.

## Decision

Native cloud secret stores are the system of record. External Secrets
Operator is the Kubernetes integration. Git may hold encrypted non-secret
config via SOPS as an escape hatch, not production credentials.

Vault is not the default. It is the hatch when native stores cannot issue
short-lived credentials the way the workload needs (for example some
database dynamic creds, or a true multi-cloud secret plane with one audit
story).

## Rationale

A platform that already runs three clouds does not need a fourth secret
cloud on day one. Native stores integrate with the IAM model we actually
use: IRSA, Azure Workload Identity, GKE WI. That is the secure path.

Vault earns its keep when you have a dedicated team to operate it, a need
for dynamic credentials, or a compliance requirement for a single secret
oracle. Without that team, Vault becomes an unpatched VM with the keys to
everything.

## Trade-offs

* Three secret APIs. The developer CLI and ESO ClusterSecretStore hide
  some of that. Not all of it.
* Native rotation features differ. We document per-cloud rotation rather
  than inventing a common rotator.
* ESO copies secrets into the cluster. Cluster RBAC and encryption at rest
  still matter. ESO is not a reason to relax that.

## Consequences

* No long-lived cloud keys in GitHub Actions. OIDC only.
* Sample service uses env vars locally and ESO in cluster.
* Secret scanning in CI is a gate. Leaked fixtures should fail the build.

## When we would reconsider

* A funded Vault (or equivalent) platform with on-call, backup and a
  tested restore.
* A single-cloud world where that cloud's native store is enough without
  ESO, using CSI drivers only.
* A decision that secrets must never land in etcd, in which case CSI
  driver sidecars replace ESO sync.

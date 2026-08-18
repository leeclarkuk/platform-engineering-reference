# Security

Security is the default path, not a specialist overlay.

## Controls in this repository

| Control | Where |
| --- | --- |
| Short-lived credentials | `docs/security/oidc.md` |
| Least privilege IAM sketches | `security/iam` |
| Policy as code | `security/policy-as-code` |
| Kubernetes PSS and NetworkPolicy | `kubernetes/base` |
| Supply chain (SBOM, signing, scan) | `security/supply-chain` |
| Secrets | ADR-006, `security/secrets` |
| Threat model | `security/threat-models` |
| Audit | CloudTrail, Azure Activity Log, Cloud Audit Logs in landing zones |

## CI gates

CI must fail on:

* Terraform that Checkov flags in the live tree
* The insecure fixture being accidentally made "compliant" without changing
  the proof script
* Secrets detected by Gitleaks
* High/critical filesystem findings Trivy reports as fixable
* Unsigned or unscanned images in the intended production path (documented
  now, enforced once registries are wired)

## Encryption

* At rest: KMS / Key Vault / Cloud KMS for disks, buckets, secrets, Terraform
  state in real deployments
* In transit: TLS at ingress. East-west is NetworkPolicy in v1, mTLS only
  with a mesh ADR

## Break-glass

Time-bounded, audited, named human. Not a standing admin role in a GitHub
team called `platform`.

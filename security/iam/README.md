# IAM

Least privilege is per-cloud:

* AWS: permission sets in Identity Center for humans, IRSA for pods,
  OIDC roles for GitHub. No IAM users in workload accounts (SCP).
* Azure: Entra PIM for standing-eligible roles, managed identities for
  compute, federated credentials for GitHub.
* GCP: groups at folder level, Workload Identity for GKE, WIF for GitHub.
  Deny user-managed service account keys with org policy.

Sketch policies belong with the module that needs them, not as a pile of
JSON in this folder. This file is the rule: identity is federated, keys
are a defect.

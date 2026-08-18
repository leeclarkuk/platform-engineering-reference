# Threat model (platform, not a single app)

## What we care about

* Standing cloud keys in CI or laptops
* Privilege escalation from a workload namespace to the hub network
* Poisoned images
* Tampering with GitOps desired state
* Silent disable of audit trails

## What we have done

* OIDC-only CI (documented)
* SCP denying IAM users/keys
* Immutable ECR, scan on push
* Restricted PSS, network policies
* Checkov gate plus an insecure fixture that must fail
* Private EKS endpoint in the module

## What we have not yet done

* Kyverno in-cluster
* Cosign verification on admission
* Break-glass access reviews as code
* Multi-cloud packet inspection

STRIDE on a new foundation change belongs in the pull request, not in a
slide deck after go-live.

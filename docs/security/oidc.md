# Workload identity and GitHub OIDC

No long-lived cloud access keys in CI. The pattern is the same everywhere:
GitHub is an identity provider, the cloud issues a short-lived credential
to a tightly scoped role, and the workflow uses that role only for the
jobs that need it.

This repository's default CI does **not** authenticate to a cloud. Lint,
validate and scan run without it. Federation is for later jobs such as
`terraform plan` against a real backend, or pushing images to ECR/ACR/
Artifact Registry.

Replace the placeholders. Do not commit real account, subscription or
project identifiers.

## GitHub side

* Create an OIDC identity provider trust is **on the cloud**, not as a
  GitHub secret.
* Restrict `sub` to `repo:<org>/<repo>:environment:<env>` or
  `repo:<org>/<repo>:ref:refs/heads/main`.
* Use GitHub Environments for `prod` with required reviewers.

```yaml
# Illustrative only. Not used by default CI.
permissions:
  id-token: write
  contents: read
```

## AWS

Terraform in `terraform/modules/aws/github-oidc` creates the provider
and three roles: `github-plan`, `github-deploy`, `github-image-publish`.
Trust is bound to `repo:<org>/<repo>` plus environments or `main`. See
[docs/aws/deployment.md](../aws/deployment.md).

Workload pods use EKS Pod Identity, not these GitHub roles. CI roles
must not be reusable as pod roles.

In the workflow: `aws-actions/configure-aws-credentials` with
`role-to-assume` and `role-session-name`. `.github/workflows/aws.yml`
skips cloud jobs when the role ARNs are unset, so pull requests stay
safe.

## Azure

1. Register an app (or use a user-assigned managed identity federated
   credential).
2. Federated credential: issuer `https://token.actions.githubusercontent.com`,
   subject matching the repo and environment, audience `api://AzureADTokenExchange`.
3. Grant the identity on the subscription or resource group: not Owner
   for CI plan jobs.
4. In the workflow: `azure/login` with `client-id`, `tenant-id`,
   `subscription-id` and `enable-AzPSSession: false`. Those IDs are
   non-secret identifiers; still prefer GitHub variables over hardcoding.

AKS uses Azure Workload Identity for pods. Do not copy the GitHub app's
client ID onto application pods.

## GCP

1. Create a Workload Identity Pool and a GitHub provider.
2. Attribute mapping: `google.subject` from `assertion.sub`, plus
   `attribute.repository` from `assertion.repository`.
3. Bind a service account with `roles/iam.workloadIdentityUser` on the
   principal set for that repository.
4. In the workflow: `google-github-actions/auth`.

GKE Workload Identity is a different binding (Kubernetes SA to GCP SA).
Keep the CI service account off application pods.

## Break-glass

If OIDC is down, humans use Identity Center / Entra / Cloud Identity.
They do not mint a 90-day access key "just for now".

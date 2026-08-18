# AWS deployment

## Prerequisites

* Terraform >= 1.10
* AWS credentials for the target account (SSO or a role, not an access key
  in Git)
* Account IDs for management, network and workload
* A GitHub organisation/user and repository name
* CIDRs that do not overlap

You do not need credentials to validate:

```bash
make verify-aws
```

## Account assumptions

See [account-model.md](account-model.md). Terraform will not create the
organisation. `allowed_account_ids` refuses to run against the wrong
account.

## State bootstrap

Each account that holds state needs the bootstrap stack once.

```bash
make deploy PROVIDER=aws ENVIRONMENT=dev STACK=bootstrap CONFIRM=yes
```

Copy `backend.hcl.example` to `backend.hcl`, fill the bucket and KMS
key from outputs, then:

```bash
terraform -chdir=terraform/aws/network init -backend-config=backend.hcl
```

S3 encryption is required. Locking uses the native S3 lockfile
(`use_lockfile = true`). DynamoDB locking is optional compatibility for
Terraform older than 1.10. Do not create both unless you are in a mixed
version estate.

Local validation always uses `-backend=false`.

## GitHub OIDC

Workload Terraform creates three roles:

| Role | Trust | Use |
| --- | --- | --- |
| `github-plan` | pull requests and named environments | `terraform plan` |
| `github-deploy` | `main` and named GitHub environments | `terraform apply` |
| `github-image-publish` | `main` and `dev` | push to ECR |

Trust is bound to `repo:<org>/<repo>:...`. There is no administrator
role. There are no access keys.

Set GitHub variables, not secrets for the role ARNs:

```text
AWS_REGION
AWS_ROLE_PLAN_ARN
AWS_ROLE_DEPLOY_ARN
AWS_ROLE_PUBLISH_ARN
ECR_REPOSITORY
```

Protect the `prod` GitHub Environment with required reviewers. The
workflow in `.github/workflows/aws.yml` plans on pull requests and
publishes images only from `main`.

## Deployment sequence

1. Bootstrap state in the network account and in the workload account.
2. Apply network in the network account.
3. Pass `transit_gateway_id`, route table IDs and (if cross-account)
   `resource_share_arn` into workload tfvars.
4. Apply workload in the workload account.
5. Cross-account only, if `manage_tgw_routes` is false: put
   `tgw_attachment_id` into network `spoke_attachments` and re-apply
   network.
6. From a path that can reach the private API (SSM to a node, VPN, or a
   temporarily restricted public endpoint): `scripts/aws/bootstrap-argocd.sh`.
7. Argo CD syncs Helm for the sample service.
8. Put the real secret value in Secrets Manager. Terraform only creates
   the container:

```bash
aws secretsmanager put-secret-value \
  --secret-id /sample-service/example-config \
  --secret-string '{"EXAMPLE_CONFIG":"hello"}'
```

```bash
make plan PROVIDER=aws ENVIRONMENT=dev STACK=network
make deploy PROVIDER=aws ENVIRONMENT=dev STACK=network CONFIRM=yes
make plan PROVIDER=aws ENVIRONMENT=dev STACK=workload
make deploy PROVIDER=aws ENVIRONMENT=dev STACK=workload CONFIRM=yes
```

## Verification

```bash
make verify-aws
make verify-live PROVIDER=aws ENVIRONMENT=dev
```

`verify-live` fails unless `GET /` on the sample service returns `ok`.
`EKS ACTIVE` and `Argo CD Synced` are not sufficient.

## Destruction

```bash
make destroy PROVIDER=aws ENVIRONMENT=dev STACK=workload
```

That prints the command. Add `CONFIRM=yes` only when you mean it.
There is no `make destroy` without provider, environment and, on AWS,
stack.

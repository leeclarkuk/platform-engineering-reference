# AWS Terraform

Three state roots, one per concern. Do not collapse them into a single
apply just because a lab has one AWS account.

```text
terraform/aws/bootstrap   S3 state bucket, KMS, optional DynamoDB lock
terraform/aws/network     Hub VPC, Transit Gateway, RAM share, DNS zone
terraform/aws/workload    Spoke VPC, EKS, ECR, GitHub OIDC, secrets
```

Account IDs are variables. Example values in `environments/*.tfvars` are
fakes. Replace them before a real apply.

## Local validation

No credentials, no backend:

```bash
make verify-aws
# or
terraform -chdir=terraform/aws/network init -backend=false
terraform -chdir=terraform/aws/network validate
```

## Apply sequence

1. Bootstrap in the account that will hold that account's state.
2. Network in the network account.
3. Workload in the workload account, passing `transit_gateway_id` and
   route table IDs from network outputs.
4. Cross-account only: pass `tgw_attachment_id` back into network
   `spoke_attachments` and re-apply network if `manage_tgw_routes` is
   false in the workload stack.

Same-account labs can set `network_account_id` and `workload_account_id`
to the same value. RAM share is skipped. `manage_tgw_routes = true`
associates the spoke attachment in the workload apply.

Remote state uses S3 encryption plus native S3 locking (`use_lockfile`).
See `backend.hcl.example` in each stack. DynamoDB locking is optional
compatibility for Terraform older than 1.10.

Plan:

```bash
make plan PROVIDER=aws ENVIRONMENT=dev STACK=network
make plan PROVIDER=aws ENVIRONMENT=dev STACK=workload
```

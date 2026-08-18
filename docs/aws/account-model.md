# AWS account model

This slice models three accounts. It does not create an AWS Organisation.

```text
Management account
    |
    +-- Network account
    |
    +-- Workload account
```

Account IDs are variables. Example tfvars use `111111111111`,
`222222222222` and `333333333333`. Replace them. Do not commit real IDs.

| Account | Terraform | Owns |
| --- | --- | --- |
| Management | `landing-zones/aws` (optional SCPs) | Organisation, billing, break-glass |
| Network | `terraform/aws/network` | Transit Gateway, hub VPC, private DNS zone, RAM share |
| Workload | `terraform/aws/workload` | Spoke VPC, EKS, ECR, GitHub OIDC, example secret |

A same-account lab is valid: set `network_account_id` and
`workload_account_id` to the same value. RAM share is skipped. That is a
lab convenience, not the production shape.

This repository does not vend accounts. Assume IDs are supplied
externally (Control Tower, AFT, or a ticket).

Humans use IAM Identity Center. GitHub uses OIDC roles in the workload
account. Workloads use EKS Pod Identity. Long-lived access keys are a
defect.

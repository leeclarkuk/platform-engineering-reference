# AWS landing zone

Organisational design for an AWS estate that looks like Control Tower
without requiring the Control Tower product.

## Intended accounts

| Account | OU | Purpose |
| --- | --- | --- |
| Management | Root | Organization, billing, Control Tower or equivalent |
| Log archive | Security | CloudTrail, Config, VPC flow logs |
| Security tooling | Security | GuardDuty org admin, Security Hub, detective work |
| Identity | Infrastructure | IAM Identity Center delegated admin |
| Network | Infrastructure | Transit Gateway, shared DNS, egress |
| Shared services | Infrastructure | CI runners, artefact mirrors |
| Workload prod/staging/dev | Workloads | Application accounts |
| Sandbox | Sandbox | Short-lived experiments, local NAT allowed |

## Terraform in this directory

The composition is intentionally small: optional Organization create, plus
SCPs that deny standing IAM users/keys and leaving the org. Attach SCPs
from the management account after OUs exist. Do not attach the access-key
deny SCP to the identity account until Identity Center is working.

Apply requires a management-account role. `terraform validate` does not.

Identity Center, account vending and AFT/Control Tower pipelines are the
next increment, not this commit. The account model is the decision. The
vending machine is an implementation detail.

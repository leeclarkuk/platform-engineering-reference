# AWS modules

Domain modules, not one-resource wrappers:

* `tags` – mandatory allocation tags
* `kms` – rotating CMK with a usable key policy
* `vpc` – subnets, route tables, TGW attachment, flow logs, endpoints
* `transit-gateway` – TGW, hub/spoke route tables, RAM, static routes
* `eks` – cluster, nodes, add-ons, Pod Identity
* `ecr` – encrypted immutable repository
* `github-oidc` – GitHub Actions roles for plan, deploy, image publish
* `secrets` – Secrets Manager container with no real secret in Git
* `security-baseline` – CloudTrail, Config, GuardDuty, Security Hub
* `budgets` – example cost ceiling

Compose them from `terraform/aws/{bootstrap,network,workload}`.

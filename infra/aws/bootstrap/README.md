# infra/aws/bootstrap (Milestone 2)

Bootstrap root is state/bootstrap prerequisites only.

* No live application resources.
* No committed live Terraform bucket name in this repo.

This root exists so the eventual remote state can be created later by the
platform owner. Milestone 2 only runs `terraform fmt -check`, `terraform
init -backend=false`, and `terraform validate`.

pstack: aws/m2-foundations


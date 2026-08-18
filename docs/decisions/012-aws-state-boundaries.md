# ADR-012: AWS Terraform state boundaries

- Status: Accepted
- Date: 2026-08-18

## Context

The first AWS composition lived in one directory. That made local
validate easy and made account boundaries fictional. A production-shaped
slice needs separate state for network and workload without inventing a
framework.

## Options considered

1. **Three roots: bootstrap, network, workload.** Outputs pass across
   stacks. RAM and TGW IDs are explicit variables.
2. **One state, two providers with assume_role.** Looks like
   multi-account. One lock, one blast radius, one apply that can break
   both accounts.
3. **Terragrunt or a custom wrapper.** Extra indirection this repository
   does not need yet.

## Decision

Separate Terraform roots for bootstrap, network and workload. Cross-stack
values travel through outputs and tfvars, not through implicit remote
state by default. Optional S3 remote state is documented per root.

Remote state uses S3 with KMS and native S3 locking (`use_lockfile`).
DynamoDB locking is retained only as compatibility for Terraform older
than 1.10.

## Rationale

Account boundaries that exist only in a diagram will be applied as one
VPC by the next person in a hurry. Separate state makes that harder.
Native S3 locking removes a DynamoDB table that existed solely for a
lock, which is the current HashiCorp recommendation.

## Trade-offs

* First apply in a cross-account TGW topology can require a second
  network apply once the spoke attachment ID exists. Same-account labs
  set `manage_tgw_routes = true` and skip that.
* Engineers must know which stack they are in. Makefile requires
  `STACK` for AWS apply and destroy.

## Consequences

* `make plan PROVIDER=aws ENVIRONMENT=dev` plans network then workload.
* `make deploy` on AWS refuses to run without `STACK`.
* Azure and GCP compositions stay single-root skeletons.

## When we would reconsider

* A shared-services account and a real remote-state data source pattern
  once more than two workload accounts exist.
* Terraform versions in the estate that cannot use S3 lockfiles.

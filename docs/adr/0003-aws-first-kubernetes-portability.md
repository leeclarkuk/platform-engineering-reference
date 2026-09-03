# ADR-0003: AWS first, Kubernetes as the portability boundary

- Status: Accepted
- Date: 2026-09-03

## Context

The organisation may already have more than one cloud. Pretending the
three providers are one product produces a fourth platform: the
abstraction. Archive Azure and GCP trees were skeletons, not parity.

## Decision

AWS is the first implementation path. Landing zones, identity, hub
networking and data platforms stay provider-native. Kubernetes (with Helm
and GitOps) is the portability boundary for twelve-factor style services,
not Terraform modules with the serial numbers filed off.

Azure and GCP implementation wait until an AWS local-validate slice exists
on **this** lineage. They will be native, not lowest-common-denominator
copies of AWS module names.

## Consequences

* Milestone 0 records the law and does not add `infra/`.
* Shared modules, when they exist, are for naming and tags only, not VPCs.
* Teams that only need a single-cloud native PaaS are not forced through
  Kubernetes by this ADR; the golden path is for services that opt in.

## Rejected options

* Azure/GCP modules in Milestone 0.
* Cross-cloud `cluster`/`network` modules with provider switches.
* Treating archive Azure/GCP READMEs as done work.

## Review trigger

A proposal to add Azure or GCP code before AWS local-validate exists on
this tree, or to share VPC/cluster modules across clouds.

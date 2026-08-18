# ADR-001: Terraform as the primary IaC tool

- Status: Accepted
- Date: 2026-08-18

## Context

The platform has to provision AWS, Azure and GCP foundations, plus a smaller
amount of supporting SaaS. The organisation will hire platform engineers, not
a dedicated CDK or Bicep guild for each cloud. The choice is which language
becomes the default for infrastructure that must be reviewed in Git.

## Options considered

1. **Terraform / OpenTofu.** One language, mature providers, plan/apply
   workflow that security and change advisory boards already understand.
2. **Cloud-native languages only** (CloudFormation, Bicep, Google KRM). Best
   fidelity per cloud, three skill sets, three review cultures.
3. **CDK / Pulumi.** Real programming languages, easier abstraction, easier
   to build an internal framework that nobody can debug at 2am.
4. **Crossplane.** Kubernetes as the control plane for cloud resources.
   Attractive if everything is already GitOps, expensive if the landing zone
   does not exist yet.

## Decision

Terraform is the primary IaC tool for cloud foundations. Kubernetes desired
state is not Terraform. Application configuration is not Terraform.

OpenTofu is an acceptable runtime if licence or supply-chain policy requires
it. Modules stay in the Terraform language, not a vendor lock-in to HashiCorp
Cloud.

## Rationale

Landing zones are where the clouds differ. Terraform still lets each
provider module look native. The alternative, three native languages, is
honest but doubles hiring and review cost before the first workload lands.

CDK and Pulumi produce better internal libraries and worse incident
debugging. The failure mode is an abstraction that only the author can
unwind. We already have that risk in the developer CLI. We do not need it in
the network hub.

Crossplane is a reasonable second control plane once clusters and GitOps are
boring. It is a poor first control plane when the cluster itself is what you
are trying to build.

## Trade-offs

* Provider bugs and API lag are real, especially on launch-week Azure and GCP
  features. Native tooling will always be slightly ahead.
* `terraform apply` on an organisation, management group or folder is still a
  sharp tool. State blast radius is an operational problem we have to design
  for.
* HCL is verbose. That verbosity is the point when the reader is a change
  reviewer, not the author.

## Consequences

* Modules are small and composable. No "enterprise landing zone" mega-module.
* Each cloud keeps its own module tree. Shared modules are for tagging,
  naming and the sample workload contract, not for VPCs.
* State is remote and locked in real deployments. This repository uses local
  state so `validate` works without credentials.

## When we would reconsider

* A single-cloud future with a strong native-language skill base.
* A decision to make Kubernetes the only control plane, with foundations
  already stable and Crossplane composition tested in failure-lab.
* Terraform licence, registry or sustainability risk that OpenTofu does not
  mitigate.

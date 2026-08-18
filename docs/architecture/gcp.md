# GCP architecture

GCP's unit of isolation is the project. Folders are how you hang IAM and
org policy. If you model this as "accounts" you will fight billing, IAM
and Shared VPC at the same time.

## Resource hierarchy

```text
Organisation
├── Folder: common
│   ├── Project: logging
│   ├── Project: security (SCC, org policies)
│   ├── Project: connectivity (hub, DNS, NCC)
│   └── Project: artifacts
├── Folder: prod
│   └── Project per product or domain
├── Folder: nonprod
└── Folder: sandbox
```

Prefer fewer, well-owned projects over a project per microservice. The
latter recreates IAM sprawl with extra steps.

## Network

Shared VPC is the native hub. Host project in `connectivity`, service
projects for workloads. GKE in service projects using Shared VPC subnets.

Network Connectivity Center is the right tool for hybrid and multi-hub
connectivity. It is not required for a single-region Shared VPC. Add it
when you have two regions, Cloud VPN/Interconnect, or another VPC that
is not a service project.

Private Service Connect for producer services. Cloud DNS private zones in
the host project, peered to service projects.

## Security

* Organisation Policy constraints for public IPs, service account key
  creation, and resource locations
* Security Command Center at organisation level
* Cloud KMS CMMs for disks, Artifact Registry and Secret Manager
* No user-managed service account keys. Workload Identity Federation for
  GitHub. GKE Workload Identity for pods.

## Compute

GKE Standard or Autopilot is an explicit choice:

* **Autopilot** if the golden path is "just run my Deployment" and you
  will live with the constraints.
* **Standard** if you need daemonsets, custom networking or failure-lab
  node kills.

This reference assumes Standard for the failure-lab's node experiment,
and documents Autopilot as the hatch for teams that do not want node
management.

Artifact Registry, not gcr.io. Binary Authorization is a later control,
once signing is actually happening in CI.

## Meaningful differences from AWS

* Folders and org policy are closer to Azure Management Groups than to
  AWS OUs/SCPs.
* Shared VPC IAM (`compute.networkUser`) is the hard part. Get that
  wrong and GKE cannot create load balancers.
* Billing exports to BigQuery are the FinOps centre of gravity, not
  Cost Explorer clones.
* VPC connectivity is global by default. That is a gift and a blast
  radius. Regional design is still your job.

Terraform skeleton: `terraform/gcp`. Narrative: `landing-zones/gcp`.

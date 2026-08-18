# GCP landing zone

Projects, folders and org policy are the model. Treat a project as closer
to an AWS account than to a resource group.

```text
Organisation
├── common (logging, security, connectivity, artifacts)
├── prod
├── nonprod
└── sandbox
```

## Native differences

* **Shared VPC** is how you centralise networking. Peering everything to
  a hub VM is an AWS habit and a bad GCP one.
* **Org Policy** denies public IPs and service account keys at folder
  scope. Do this before the first GKE cluster.
* **Workload Identity Federation** for GitHub. No JSON keys in CI.
* **Security Command Center** at org level, not per project as an
  afterthought.
* **Billing export to BigQuery** is the FinOps backbone.

GKE in a service project using host-project subnets is the golden path.
Autopilot is the hatch for teams that should not manage nodes.
Network Connectivity Center waits until you have hybrid or multi-region
hubs worth operating.

Terraform skeleton: `terraform/gcp`.

# Azure architecture

Azure is not "AWS with different resource names". Copying Transit Gateway
into a VNet diagram will give you a network that fights the platform.

## Management model

```text
Tenant (Entra ID)
└── Management groups
    ├── Platform
    │   ├── Identity
    │   ├── Connectivity
    │   └── Management (logs, Defender)
    ├── Landing zones
    │   ├── Prod
    │   └── Nonprod
    └── Sandbox
```

Subscriptions are the billing and isolation boundary. They are closer to
AWS accounts than resource groups are. Resource groups are deployment
units, not security perimeters.

Entra ID is the identity plane. Workload identity federation for GitHub
and Azure Workload Identity for AKS replace service principals with
standing secrets.

## Network

Hub-and-spoke VNets with a connectivity subscription. Azure Firewall or
a third-party NVA in the hub for egress and inspection.

**Virtual WAN** is justified when you have many regions, many branches, or
you want Microsoft to run the hub routers. It is not justified because a
reference architecture diagram used it. This repository starts with
classic hub-and-spoke and documents Virtual WAN as the scale-up path.

Private DNS zones live in the connectivity subscription and are linked to
spokes. Private Endpoints are the default for Key Vault, ACR and data
services. Public PaaS endpoints are an exception.

## Policy and security

Azure Policy at management group scope is the SCP analogue, and it is
better at deploy-if-not-exists than SCPs are. Use it. Do not rebuild it
in OPA unless you have a cross-cloud policy team that actually exists.

Defender for Cloud is the GuardDuty/Security Hub analogue. It is not
optional on production subscriptions.

Key Vault is the secret store. Purge protection on in staging and prod.

## Compute

AKS with Azure CNI (overlay is acceptable for density; document the
choice), Azure Workload Identity, and Azure Monitor Container Insights
plus Prometheus metrics via the in-cluster stack.

ACR sits in the platform subscription. AKS pulls via private endpoint and
managed identity. Admin user disabled.

## Meaningful differences from AWS

* Management groups + subscriptions, not OUs + accounts. Billing alerts
  land differently.
* Azure Policy can remediate, not only deny.
* Identity is tenant-wide. A bad Entra app registration is a tenant
  incident, not an account incident.
* Networking SKUs and peering limits will shape the hub earlier than TGW
  typically does.
* Activity Logs plus diagnostic settings are not CloudTrail. You have to
  design the Log Analytics workspace topology or you will pay for a
  duplicate of every subscription's logs.

Terraform skeleton: `terraform/azure`. Narrative: `landing-zones/azure`.

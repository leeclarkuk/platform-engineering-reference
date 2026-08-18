# Azure landing zone

Use the Cloud Adoption Framework management group tree, not an AWS OU
translation.

```text
Tenant Root
├── Platform
│   ├── Identity
│   ├── Management
│   └── Connectivity
├── Landing Zones
│   ├── Corp
│   └── Online
└── Sandbox
```

## Native differences you should not paper over

* **Subscriptions** are the isolation and billing unit. Resource groups
  are not mini-accounts.
* **Azure Policy** can deploy missing diagnostics. SCPs cannot. Use that.
* **Entra ID** is tenant-scoped. App registrations are a tenant risk.
* **Hub-and-spoke first**, Virtual WAN when branches and regions make
  Microsoft-operated hubs cheaper than your own routers.
* **Private DNS** belongs in Connectivity and is linked to spokes.
  Do not create a private zone per team and hope.

AKS landing zones need: Azure Workload Identity, private ACR, Azure
Monitor, and a decision on Azure CNI Overlay versus traditional CNI
before the first node pool.

Terraform skeleton: `terraform/azure`.

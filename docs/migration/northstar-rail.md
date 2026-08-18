# Northstar Rail: legacy migration

Northstar Rail is a fictional operator. The estate is typical: VMware,
Linux and Windows VMs, Oracle, hand-built networks, site-to-site VPNs,
shared credentials, thin monitoring, deployments that work if a specific
person is in the room.

The goal is a safer estate and a faster path for **new** work. It is not
to rewrite everything into microservices so that a diagram looks modern.

```text
Legacy estate
    -> Cloud foundations
    -> Hybrid connectivity
    -> Workload migration
    -> Containerisation where justified
    -> GitOps
    -> Developer platform
    -> Legacy retirement
```

## 1. Legacy estate

Write down what is actually there. Owners, SLAs, data classification,
change windows, Oracle versions, Windows domain dependencies, VPN
concentrators. If this step is skipped, every later step is theatre.

Leave these alone until foundations exist:

* Oracle RAC that currently works
* Signalling-adjacent or safety-related systems with a certification
  boundary
* Anything whose recovery has never been tested, until you have a lab

## 2. Cloud foundations

Build the landing zone on the home cloud first (assume AWS here, the
same sequence applies on Azure or GCP). Identity Center, logging
accounts, hub network, SCPs. No application migrations into a
subscription that cannot tell you who did what.

## 3. Hybrid connectivity

One designed path: VPN or Direct Connect / ExpressRoute / Interconnect
into the hub. Stop adding one-off tunnels per project. DNS is the
usual silent killer. Decide which side owns which zones before the
first VM moves.

## 4. Workload migration

Move in this order:

1. New services on the golden path (no legacy debt)
2. Stateless Linux apps that are already packages
3. Windows apps that can lift to VMs in the cloud without a rewrite
4. Oracle: RDS Custom, Exa, or stay put. This is a data decision.

Rehost (VM in cloud) is a valid target. Replatform (managed DB, object
storage) when the operational gain is real. Refactor when the
application is being changed anyway.

**Leaving a workload alone is often the correct engineering decision.**
A stable Windows service with one owner, no change demand, and a known
backup is cheaper on VMware than a six-month Kubernetes rewrite that
nobody asked to operate.

## 5. Containerisation where justified

Containerise when you need the golden path: repeatable deploys, identity
federation, horizontal scale, or a team that already runs Kubernetes
well. Do not containerise Oracle. Do not containerise a vendor desktop
app. Do not containerise because "the platform team prefers YAML".

## 6. GitOps

Once something is a container, it deploys through Argo CD. CI still
does not kubectl to production. Legacy VM pipelines can remain until
retirement. Dual processes are allowed. Dual undocumented processes
are not.

## 7. Developer platform

Only after a handful of services exist on the path. CLI and templates
beat a portal. Northstar should not start here. Starting here is how
you get a catalogue of VMs with cute logos.

## 8. Legacy retirement

Each remaining VMware cluster needs a date, an owner and a budget line
for decommission. Parallel running without a shutdown criterion is
how you pay two estates forever.

Shared credentials die with the identity project, not with a "we'll
rotate later" ticket. If a system cannot survive credential rotation,
that is a finding, not a reason to keep the password in a shared inbox.

## What success looks like

* New work defaults to the golden path
* Hybrid connectivity is boring
* Oracle has a named strategy, even if that strategy is "stay"
* You can name the last VMware host and when it powers off
* Incidents no longer depend on one engineer remembering a VPN PSK

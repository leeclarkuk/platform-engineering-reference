# ADR-005: Centralised versus distributed networking

- Status: Accepted
- Date: 2026-08-18

## Context

Hub-and-spoke is the enterprise default. Fully distributed VPC peering is
how start-ups begin. Transit Gateway, Azure Virtual WAN and Network
Connectivity Center all encode a centralisation choice that is hard to
unwind.

## Options considered

1. **Centralised hub.** Shared inspection, egress, hybrid connectivity and
   DNS. Spokes are workload VPCs/VNets/projects. Traffic to the internet
   and on-prem goes via the hub.
2. **Distributed.** Each environment peers as needed. NAT and VPN live with
   the workload. Fast to start, messy at fifty VPCs.
3. **Hybrid.** Production and shared services through a hub. Sandboxes
   internet-facing with local NAT and strong account isolation.

## Decision

Production, staging and shared services use a centralised hub. Sandboxes may
use local egress. The hub is a product with an SLO, not a box in a diagram.

On AWS that hub is Transit Gateway plus a dedicated network account. On
Azure it is hub-and-spoke, with Virtual WAN when the number of regions and
branches justifies the extra control plane. On GCP it is Shared VPC plus
Network Connectivity Center for hybrid and multi-region.

## Rationale

Centralised egress is how you make "no public IP on workloads" true,
enforce inspection, and keep hybrid connectivity from becoming a mesh of
one-off VPNs. Distributed networking is simpler until the second on-prem
path and the first audit of internet egress.

Virtual WAN is not the Azure default in this reference because it is easy to
buy a global transit product before you have a routing design. Start with
hub-and-spoke. Move to Virtual WAN when branches, many regions or a need for
managed hubs show up as real requirements.

## Trade-offs

* The hub is a shared fate domain. A bad route or NAT change can affect
  every spoke. Change control here is not optional.
* Centralised NAT and inspection cost money and add latency. That is usually
  cheaper than ungoverned egress, but it is not free.
* Troubleshooting requires network engineers who understand the hub. You
  cannot hide this behind self-service without also hiding the blast radius.

## Consequences

* Workload modules attach to the hub. They do not create their own VPN.
* Failure-lab includes "remove a route" and "break DNS", not just pod kills.
* Multi-cloud networking is an explicit product with a named owner, or it
  does not exist.

## When we would reconsider

* A small estate (a handful of accounts, one region, no hybrid) where a hub
  is ceremony.
* A zero-trust service-to-service model that actually replaces east-west
  VPC routing rather than sitting on top of it.
* Azure estates with many branches where Virtual WAN is the simpler
  operational model from day one.

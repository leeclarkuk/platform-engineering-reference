# ADR-004: Multi-cloud strategy

- Status: Accepted
- Date: 2026-08-18

## Context

The organisation may already have AWS, Azure and GCP for historical,
commercial or product reasons. "We are multi-cloud" is often a slogan that
creates a fourth platform: the abstraction, plus three real ones.

## Options considered

1. **Intentional multi-cloud.** Each provider is first-class. Portability at
   Kubernetes. No LCM abstraction. Native services preferred.
2. **Primary plus disaster-recovery secondary.** One cloud runs production.
   Another is cold or warm DR. Cheaper than active-active, still expensive.
3. **Active-active across clouds.** Rarely justified. Data consistency,
   identity, networking and failover testing dominate the cost.
4. **Single cloud.** Lowest operational cost. Best engineering. Politically
   unavailable in some enterprises.

## Decision

This reference implements intentional multi-cloud at the platform layer, not
active-active applications. A workload has a home cloud. It can be rebuilt
on another cloud through the Kubernetes contract if the data layer allows it.

We do not imply that multi-cloud is desirable. We imply that it is sometimes
required, and that the cost should be visible.

## Rationale

Enterprises collect clouds the way they collect identity providers: by
acquisition, by vendor relationship, by a team that could not get an AWS
account. Pretending that will be consolidated next quarter is how you get an
unmanaged estate.

The useful move is to standardise the developer path and the reliability
model, while letting each cloud be good at being itself. The expensive move
is to stretch a single network and a single identity model across all three
and then wonder why every incident involves DNS.

## Trade-offs

* Three security baselines, three billing tools, three IAM models.
* Data transfer and private connectivity between clouds are a product, not a
  line on a diagram. See `networking/multi-cloud`.
* Hiring is harder. The platform team needs T-shaped engineers, not three
  separate churches.

## Consequences

* AWS is deepest because that is the common starting point, not because the
  others are toys.
* Shared documentation language (environment names, SLOs, tags, golden
  paths) is mandatory. Shared Terraform modules for VPCs are not.
* Cross-cloud failover is out of scope until a named workload has a tested
  RPO/RTO that requires it.

## When we would reconsider

* A board-level single-cloud mandate with a funded exit from the others.
* A regulator or customer that requires active-active in two providers. Then
  we would fund it as a product, with a dedicated reliability programme,
  not as a Terraform `count`.

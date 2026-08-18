# ADR-010: Reliability and failure testing

- Status: Accepted
- Date: 2026-08-18

## Context

A control plane reporting healthy does not prove that real application
traffic is healthy. Kubernetes ready probes, Transit Gateway attachments
and Argo CD sync status can all be green while users cannot log in.

## Options considered

1. **Failure-lab as a documented, repeatable experiment programme.** Manual
   or lightly scripted. Game days on a cadence. No random production chaos.
2. **Continuous chaos in production** (unsupervised Chaos Monkey).
3. **Tabletop only.** Cheap, does not find the DNS TTL you forgot.
4. **Vendor chaos suite as the programme.** Useful tooling, still needs
   hypotheses and ownership.

## Decision

Reliability work is a failure-lab with written experiments, plus scheduled
game days. Chaos tooling may automate injection later. It does not replace
the write-up.

Each experiment uses: hypothesis, setup, failure injected, expected
behaviour, observed behaviour, detection, recovery, MTTR, SLO impact,
lessons, permanent improvement.

## Rationale

Chaos without a hypothesis is vandalism with metrics. Most organisations
are not ready for unsupervised production failure. They are ready to kill a
pod in staging on Thursday and notice that nobody got paged.

The experiments in this repository include application, node, DNS, routing,
IAM, certificates, VPN, resource exhaustion, GitOps and dependency failure.
That list is deliberate. It is the set of things that actually take
platforms down.

## Trade-offs

* Manual experiments do not scale to hundreds of services. They scale to
  learning. Automation comes after the first ten write-ups exist.
* Game days cost delivery time. That time is cheaper than the first
  untested failover.
* Some experiments (remove IAM permission, expire a certificate) are
  dangerous in shared hubs. They run in non-production or in a dedicated
  lab account.

## Consequences

* SLOs are not complete without a matching experiment that would burn the
  error budget.
* "We have Prometheus" is not a reliability strategy.
* Application teams own their experiment for the user path. Platform teams
  own experiments for shared network, identity and GitOps.

## When we would reconsider

* A mature error-budget culture and a dedicated reliability team that can
  run guarded, supervised production chaos.
* Regulatory constraints that forbid injection. Then we invest more in
  staging fidelity and game-day production-like environments, not in
  pretending tablets count as tests.

# Engineering operating model

Platform engineering is a product. It is not a ticket queue with nicer
diagrams. This document is the working agreement.

## Ownership

| Thing | Owner | Notes |
| --- | --- | --- |
| Landing zones, hub network, org policy | Platform | Shared fate. Change-controlled. |
| EKS/AKS/GKE control plane and add-ons | Platform | Application teams do not SSH to nodes. |
| Golden path templates, CLI, CI org workflows | Platform | Versioned. Breaking changes announced. |
| Application code, Helm values, SLO, runbook | Application team | They page first. |
| Data stores created through a golden path | Application team | Platform owns the path, not the data. |
| Escape-hatch infrastructure | Named team | Extra review, extra cost, extra toil. |

If two names are listed, nobody owns it. Pick one.

## Platform team responsibilities

* Keep foundations reproducible and boring
* Make the secure path the default
* Publish a small interface: CLI, templates, docs, SLO for the platform
  itself
* Run the failure-lab for shared systems
* Say no to snowflake clusters without offering a hatch

## Application team responsibilities

* Use the golden path unless they have a written reason not to
* Own SLIs, dashboards and the user-path runbook
* Do not store secrets in Git
* Show up to game days that involve their service

## Golden paths and escape hatches

The golden path is: `platform create service`, GitHub Actions, signed
image, Argo CD, restricted PSS, workload identity, default SLO.

Escape hatches (examples):

* VM for a vendor appliance
* Cloud-native PaaS (Lambda, Azure Functions, Cloud Run) when Kubernetes
  is unjustified
* Direct Terraform in a workload account for a managed database the path
  does not offer yet
* A dedicated cluster for a compliance boundary

Hatch requests need: owner, expiry or review date, extra controls, and
who gets paged. Permanent unmarked hatches are just shadow IT.

## Production readiness

A service may go to production when:

* It has probes, limits, PDB, ownership tags and a runbook
* SLIs are defined and alerting is wired
* Secrets come from the native store
* The image is scanned and signed
* A staging deploy has been done via GitOps, not from a laptop

This list is short on purpose. Scorecards with forty checks are how you
teach teams to ignore checks.

## Incidents

* User-path symptoms page the application team
* Platform pages on Argo CD, ingress, cluster control plane, hub network,
  identity
* A control plane that is green does not close the incident
* Blameless write-ups live in `docs/runbooks` or the team's repo. Action
  items that change the platform become ADRs or code

## Technical and architecture governance

* ADRs for binding decisions
* Terraform and Helm review in Git, not in a weekly architecture board
  that cannot remember the last ten decisions
* Standards are in CI. If it is not enforced, it is a blog post
* Architecture review is for hatches and new foundations, not for every
  CRUD service

## SLO ownership

Application SLO: application team. Platform SLO (API server availability,
ingress, artefact pull, Argo CD sync): platform team. Error budgets are
how we decide whether to feature-work or reliability-work. They are not
a punishment system.

## Cognitive load

If an application engineer needs to know TGW route table IDs to ship a
handler, the platform has failed. If a platform engineer needs to know
every team's schema to change a node AMI, the boundary has failed the
other way.

## Build versus buy

Buy undifferentiated control planes when the market is mature and you
will not staff them (identity SaaS, some observability backends). Build
the golden path and the wiring. Do not buy a "platform" that is a
dashboard over Terraform you still have to write.

## Legacy retirement

Retirement is a project with a date and an owner. Parallel run without a
decommission date is how VMware estates become eternal. See the
Northstar Rail case study.

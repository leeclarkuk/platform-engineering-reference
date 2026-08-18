# Engineering principles

These are operating constraints, not posters. If a change violates one of
them, the change needs an ADR, not a comment in Terraform.

## 1. Prefer boring, proven technology over unnecessary novelty

Platforms fail in operations, not in architecture reviews. Kubernetes,
Terraform, Argo CD, Prometheus and the hyperscaler control planes are already
complex. Adding a service mesh, a custom control plane or a new policy
language has to earn its keep against paging load, skills and failure modes.

## 2. Automate repeatable work

If a human does the same privileged change twice, it becomes a pipeline or a
module. Automation is for the boring path. Judgement stays with people.

## 3. Make the secure path the easiest path

Golden paths ship with workload identity, network policy, non-root containers,
resource limits, encryption and audit already on. Escape hatches exist. They
are explicit, reviewed and more expensive in process than the default.

## 4. Git is the source of truth for platform configuration

Clusters, policies and application desired state are declared in Git. ClickOps
is an incident, not a workflow. Exceptions are break-glass and are time-bounded.

## 5. Use short-lived credentials rather than permanent cloud access keys

Humans use identity federation. CI uses OIDC. Workloads use native identity
(IRSA, Azure Workload Identity, GKE Workload Identity). Standing keys are a
defect.

## 6. Infrastructure must be reproducible

Another engineer, or this repository in six months, must be able to recreate
the intent from Git. Snowflakes are legacy, even if they run in a cloud
account.

## 7. Platforms should reduce cognitive load for application teams

Application engineers should think about their service, SLO and data, not
about Transit Gateway attachments. The platform team absorbs that complexity
and publishes a small interface.

## 8. Observability must be designed in rather than bolted on later

Logs, metrics and traces ship with the golden path. A service that cannot be
debugged in production is not ready, regardless of how green the pipeline is.

## 9. Reliability is a measurable engineering property

SLIs, SLOs and error budgets are how we decide whether to ship. Uptime
opinions in Slack are not.

## 10. Cloud portability should exist at sensible abstraction boundaries

We portable the workload contract (container, Helm, GitOps, identity
annotations, SLO shape). We do not portable the landing zone. AWS Organizations
is not Azure Management Groups with extra steps.

## 11. Do not create a lowest-common-denominator multi-cloud platform

If Azure Policy is the right control, use it. Do not invent a custom engine
so that AWS and GCP can pretend to match. Teams pay for the worst of all
three providers when you do that.

## 12. Prefer provider-native capabilities where they materially improve the platform

GuardDuty, Defender for Cloud and Security Command Center are not
interchangeable, and that is fine. Native services reduce undifferentiated
toil when they are actually operated.

## 13. Architecture decisions should explicitly document trade-offs

ADRs record what we gave up. If every alternative looks stupid, the ADR is
theatre. See `docs/decisions/`.

## 14. Cost is an architectural concern

NAT gateways, cross-AZ traffic, verbose logs, idle nodes and multi-cloud
data transfer show up on the invoice before they show up in a design review.
FinOps is part of the design, not a quarterly clean-up.

## 15. Golden paths cover roughly 80% of cases, with explicit escape hatches

The remaining 20% is real: Oracle, Windows, latency-critical networks,
vendor appliances. The platform does not pretend those workloads do not
exist. It names the hatch, the owner and the extra operational cost.

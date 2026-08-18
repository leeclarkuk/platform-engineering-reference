# Remove a network route

**Hypothesis:** A missing default or TGW route presents as a random
timeout, not as a routing incident.

**Setup:** Spoke VPC with a known path to a dependency (hub, on-prem,
or NAT).

**Failure injected:** Delete the 0.0.0.0/0 to NAT, or the TGW route to
the shared services VPC. Lab account only.

**Expected behaviour:** Egress to that prefix dies. In-cluster traffic
may look fine. Argo CD may still show Healthy.

**Observed behaviour:** _Fill when run._

**Detection:** Flow logs, NAT metrics, user-path timeouts.

**Recovery:** Re-apply Terraform or restore the route table. Do not
"fix" it in the console without a follow-up PR.

**MTTR:** _Fill when run._

**SLO impact:** Full outage for anything that needed that path.

**Lessons:** Hub changes need change control because they are shared
fate.

**Permanent improvement:** Route table tests in the pipeline where
possible; packet tests in staging where not.

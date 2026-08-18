# Simulate dependency failure

**Hypothesis:** The service's `/health` stays OK while `/` fails if
health does not call the dependency. That is either correct (don't
flap kubelet) or a lie (users are down).

**Setup:** Sample service calling a fake dependency (later increment)
or a network policy deny to a required peer.

**Failure injected:** NetworkPolicy deny, or scale the dependency to
zero, or make it return 500.

**Expected behaviour:** User path fails. Platform looks healthy.
Error budget burns.

**Observed behaviour:** _Fill when run._

**Detection:** User-path SLI, dependency error traces. Not
`kube_deployment_status_replicas_available`.

**Recovery:** Restore the dependency or the policy. Circuit breaking
is an application concern; it is not a mesh requirement.

**MTTR:** _Fill when run._

**SLO impact:** This _is_ the SLO, if the dependency is on the user
path.

**Lessons:** Test the user path.

**Permanent improvement:** A synthetic that executes the same
dependency chain as a user. Document which failures should make
`/ready` fail.

# Kill an application pod

**Hypothesis:** With two replicas and a PDB, killing one pod does not
take the user path down. Readiness removes the pod from service before
SIGTERM finishes.

**Setup:** Sample service on the golden path, two replicas, PDB
minAvailable 1, load on `/`.

**Failure injected:** `kubectl delete pod` on one replica (or a SIGKILL).

**Expected behaviour:** In-flight requests to the dying pod may fail.
New requests succeed. No page if error rate stays inside the burn rate.

**Observed behaviour:** _Fill when run._

**Detection:** HPA/replica count, 5xx on the user path, not kubelet
ready on the node.

**Recovery:** ReplicaSet creates a replacement. No human.

**MTTR:** _Fill when run._

**SLO impact:** Small, unless connections stick to the dead pod.

**Lessons:** _Fill when run._

**Permanent improvement:** Confirm preStop + deregistration delay on
the load balancer. If users saw a burst of 5xx, the probe or grace
period is wrong.

# Terminate a Kubernetes node

**Hypothesis:** The cluster autoscaler or managed node group replaces
the node. Pods reschedule. The user path dips, it does not die.

**Setup:** At least two nodes. Sample service not pinned to one node.

**Failure injected:** Cordon+drain, or stop the instance/VM/node.

**Expected behaviour:** Pods move. PDBs delay drain. Cluster reports
node NotReady. Application 5xx only during reschedule.

**Observed behaviour:** _Fill when run._

**Detection:** Node alerts, pod Pending, error budget burn.

**Recovery:** Node group creates a replacement. Drain should be the
normal path; hard stop tests the abnormal one.

**MTTR:** _Fill when run._

**SLO impact:** Minutes, not hours, if PDB and replica count are real.

**Lessons:** _Fill when run._

**Permanent improvement:** If pods stay Pending, you undersized the
node group or used a hostPath you should not have.

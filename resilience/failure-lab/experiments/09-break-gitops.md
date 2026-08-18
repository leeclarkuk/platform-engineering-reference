# Break a GitOps deployment

**Hypothesis:** A bad Helm value or a failed sync will not be noticed
if teams only watch GitHub Actions.

**Setup:** Argo CD managing sample-service. A known-good sync.

**Failure injected:** Push an invalid manifest, or set auto-sync off
and diverge, or point image at a digest that does not exist.

**Expected behaviour:** Argo CD Degraded/Unknown. Cluster may still
run the old version (good) or go empty (bad). Users may be fine.

**Observed behaviour:** _Fill when run._

**Detection:** Argo CD application health, image pull errors. CI may
be green if it never talked to the cluster.

**Recovery:** Revert Git. Do not kubectl overlay a fix without
recording it.

**MTTR:** _Fill when run._

**SLO impact:** Zero if old pods remain; full if you pruned into a
hole.

**Lessons:** GitOps needs its own SLO.

**Permanent improvement:** Alert on OutOfSync/Degraded. Ban prune on
first production apps until someone has been paged for it.

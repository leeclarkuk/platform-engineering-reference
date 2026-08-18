# Exhaust application resources

**Hypothesis:** CPU throttling or memory OOM looks like "slowness"
then a crash loop. Limits are doing their job, or they are too tight.

**Setup:** Sample service with the golden-path requests/limits. A load
generator.

**Failure injected:** Drive CPU or allocate memory until throttle/OOM.

**Expected behaviour:** Latency rises, then restarts if OOM. HPA may
add pods if the metric is CPU.

**Observed behaviour:** _Fill when run._

**Detection:** Throttling metrics, OOMKills, latency SLI.

**Recovery:** Traffic drops or HPA/scale. Humans raise limits only
with evidence.

**MTTR:** _Fill when run._

**SLO impact:** Latency budget dies first.

**Lessons:** Limits without load tests are guesswork.

**Permanent improvement:** A load test in staging that is part of
readiness, not a one-off.

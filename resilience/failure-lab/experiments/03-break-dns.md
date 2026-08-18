# Break DNS resolution

**Hypothesis:** Application failures will look like "the database is
down" or "the API is down". The actual fault is CoreDNS or a private
zone association.

**Setup:** Sample service calling an in-cluster or private hosted name.

**Failure injected:** Scale CoreDNS to zero, or remove a Route 53 /
Private DNS association, or poison a resolver rule.

**Expected behaviour:** New egress by name fails. Existing connections
may continue. `/health` may still pass if it does not resolve anything.

**Observed behaviour:** _Fill when run._

**Detection:** DNS error metrics, not CPU. User-path synthetic that
uses names, not IPs.

**Recovery:** Restore CoreDNS or the zone association. Flush caches
if you use a low TTL. You probably do not.

**MTTR:** _Fill when run._

**SLO impact:** Often 100% user-path failure with green kubelets.

**Lessons:** This is why `/health` is not an SLI.

**Permanent improvement:** Synthetic checks that resolve the names
users resolve. Alert on CoreDNS availability.

# Remove an IAM permission

**Hypothesis:** IRSA/Workload Identity failures look like application
bugs. The pod is Running.

**Setup:** Sample service reading a secret or S3 object via workload
identity.

**Failure injected:** Remove `s3:GetObject` or the equivalent Key Vault
get, or break the trust policy on the role.

**Expected behaviour:** New calls fail with 403. `/ready` may still pass
if it does not exercise the dependency. That is the point.

**Observed behaviour:** _Fill when run._

**Detection:** CloudTrail / Activity Log / Cloud Audit Logs, application
error logs with access denied.

**Recovery:** Restore the policy. If someone "fixed" it by minting
static keys, that is a worse incident.

**MTTR:** _Fill when run._

**SLO impact:** Feature-level or full, depending on the dependency.

**Lessons:** Ready probes should include critical dependency checks
carefully: too much and you flap; too little and you lie.

**Permanent improvement:** A synthetic that uses the same identity as
the app.

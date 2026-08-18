# Expire or invalidate a certificate

**Hypothesis:** Certificate expiry is still one of the most reliable
ways to create a Saturday incident.

**Setup:** Ingress or load balancer TLS for the sample service.

**Failure injected:** Short-lived lab cert allowed to expire, or
delete the secret the ingress reads.

**Expected behaviour:** Clients fail TLS. HTTP from inside the cluster
to the Service may still work. Users do not use that path.

**Observed behaviour:** _Fill when run._

**Detection:** Certificate expiry exporter, synthetic TLS checks from
outside the cluster. Not kubelet.

**Recovery:** Restore the cert, restart nothing if the ingress watches
the secret, restart if it does not.

**MTTR:** _Fill when run._

**SLO impact:** Full user-path outage, often with "but curl from the
pod works".

**Lessons:** Measure what users do.

**Permanent improvement:** Automated issuance (ACM, cert-manager) plus
an alert 30 days out that someone owns.

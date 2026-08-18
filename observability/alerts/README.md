# Alerts

Page on SLI burn, not on CPU averages. The sample service examples are
in `sample-service.yaml`:

* User-path 5xx above 1 percent for 10 minutes
* p95 latency above 300ms for 15 minutes
* Ready replicas below spec for 5 minutes

If an alert has no owner, it is noise. Delete it.

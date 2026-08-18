# SLOs

Sample service example:

```text
Availability: 99.9%
Latency: 95% of requests below 300ms
```

These are examples. 99.9% is about 8.8 hours of error budget a year.
A customer-facing API might need that. An internal report generator
usually does not. A safety-related system might need something
stricter and a different assurance model entirely.

SLI is the user path, not `/health`. Error budget is owned by the
application team. Platform SLOs are separate (API server, ingress,
GitOps).

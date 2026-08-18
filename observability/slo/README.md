# SLOs

Sample service example, measured by `observability/prometheus/rules`:

```text
Availability: 99.9%
Latency: 95% of requests below 300ms
```

These are demonstration targets. 99.9% is about 8.8 hours of error
budget a year. A customer-facing API might need that. An internal
report generator usually does not.

SLI is `GET /`, not `/health`. Error budget is owned by the application
team. Platform SLOs are separate (API server, ingress, GitOps).

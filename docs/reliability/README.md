# Reliability

Reliability is measured. See ADR-010 and `resilience/failure-lab`.

The sample service example SLO:

* Availability: 99.9%
* Latency: 95% of requests below 300ms

Those values are **examples**. 99.9% is about 8.8 hours of error budget
per year. A railway passenger-information API and an internal report
generator should not share it. Set SLOs from user harm, not from
percentage fashion.

SLIs we actually use for the sample API:

* Availability: non-5xx ratio on the authenticated user path, not on
  `/health`
* Latency: histogram on the user path
* Saturation: event loop / goroutine count is a diagnostic, not an SLI

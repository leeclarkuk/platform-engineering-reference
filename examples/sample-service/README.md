# Sample service

Production-shaped Go API used to prove the platform. It is not a
product.

* `GET /` - service identity
* `GET /health` - liveness
* `GET /ready` - readiness (set `READY=false` to fail)
* `GET /metrics` - Prometheus

Structured JSON logs, graceful shutdown, env-based config. In cluster,
`EXAMPLE_CONFIG` comes from Secrets Manager via External Secrets Operator.

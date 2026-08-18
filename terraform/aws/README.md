# AWS Terraform composition

One composition, three environments. CIDRs, HA and budgets change. The
module tree does not.

```bash
make plan PROVIDER=aws ENVIRONMENT=dev
```

`validate` uses `-backend=false` and does not need credentials. `plan`
against a real account needs the OIDC role in `docs/security/oidc.md`.

In a real organisation the Transit Gateway lives in the network account
and spokes pass `transit_gateway_id`. `create_transit_gateway` exists so
this reference can be applied in a single account lab. Do not run
production that way.

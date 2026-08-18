# Contributing

This repository is a reference implementation. Contributions should make it
more useful to someone who has to operate a platform, not more impressive in
a diagram.

## Before you open a pull request

1. Read `docs/principles/README.md` and the relevant ADR in `docs/decisions/`.
2. Prefer a small, complete change over a large incomplete one.
3. If the change is architectural, add or update an ADR. Do not bury a
   strategy change in Terraform comments.
4. Do not add a cloud resource that cannot be validated without live
   credentials unless it is clearly marked documentation-only.

## Local checks

```bash
make init
make lint
make test
make validate
make security
```

`make deploy` and `make destroy` require an explicit `PROVIDER` and
`ENVIRONMENT`. AWS also requires `STACK`. They are not part of the
default contribution path.

## What we will reject

* Lowest-common-denominator abstractions that hide AWS, Azure or GCP
  differences
* Service mesh additions without an ADR explaining the operational cost
* Modules that try to model an entire landing zone in one resource graph
* Placeholder files that only exist to fill a directory
* Credentials, account IDs, customer names or employer-specific architecture

## Pull request shape

Use the template. Keep the description short: what changed, why, how you
proved it, and what you did not prove.

One concern per pull request. A Terraform module, a documentation correction
and a CLI feature do not belong together unless they are the same change.

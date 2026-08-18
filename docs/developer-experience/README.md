# Developer experience

The product is time-to-safe-production, not the number of templates.

## Default path

```bash
platform create service payments-api
cd payments-api
# implement handlers
git push
```

CI tests, scans, builds, produces an SBOM and signs. A promotion path
updates GitOps. Argo CD syncs. The team watches their SLO, not the
node AMI.

## What the path includes

* Go service skeleton (other languages later)
* Dockerfile, non-root
* GitHub Actions
* Helm chart with probes, limits, PDB
* Ownership metadata in the catalogue
* Default SLO document (example numbers, to be edited)
* Runbook stub

## What it does not include

* Cloud account vending (platform-team change)
* A mesh
* A GUI

See ADR-007 and ADR-009.

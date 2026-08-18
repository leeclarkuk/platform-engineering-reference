# FinOps

Cost is an architectural concern. Numbers in this repository are
**models**, not quotes. Plug in your own unit costs.

See `finops/` for tagging, budgets and per-cloud models.

Mandatory allocation keys:

* `Owner` (team)
* `Environment` (`dev` / `staging` / `prod`)
* `CostCentre`
* `Service`
* `DataClassification`

Untagged resources are a defect in production. SCPs / Azure Policy /
org policy should enforce the keys even if the values start messy.

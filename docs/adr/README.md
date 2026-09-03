# Architecture decision records

Binding decisions for **this** tree, starting from empty `main`
(`1407188077d1ce05eccfc03e9354b8ea951b67fd`). Archive ADRs on `recover/*`
are historical. They are not imported as files and are not in force here
until restated.

Status is `proposed`, `accepted`, `superseded` or `rejected`.

| ID | Title | Status |
| --- | --- | --- |
| [0001](0001-empty-main-source-of-truth.md) | Empty main is the source of truth; recover branches are archive only | Accepted |
| [0002](0002-terraform-vs-argocd-ownership.md) | Terraform versus Argo CD ownership, including Pod Identity versus ServiceAccount | Accepted |
| [0003](0003-aws-first-kubernetes-portability.md) | AWS first, Kubernetes as the portability boundary | Accepted |
| [0004](0004-helm-only-golden-path.md) | Helm-only golden path; no second workload manifest set | Accepted |
| [0005](0005-exclusions-backstage-crossplane-mesh-ai.md) | No Backstage, Crossplane, service mesh, or AI control plane | Accepted |
| [0006](0006-frictionctl-pin-format.md) | frictionctl pin format | Accepted |

New ADRs take the next number. Do not rewrite history. Supersede instead.

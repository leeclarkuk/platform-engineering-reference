# Kubernetes platform

One contract, three overlays.

```text
kubernetes/base          common Deployment shape, policies, PDB, limits
kubernetes/eks           IRSA annotations, gp3 storage, NLB notes
kubernetes/aks           Azure Workload Identity, Azure disk
kubernetes/gke           GKE WI, PDCSI
```

## What ships on every cluster

* Namespaces per service, not per team-of-teams unless you have a tenancy
  model that needs it
* Pod Security Standards: `restricted` for golden-path namespaces
* NetworkPolicy default-deny ingress inside the namespace, allow DNS and
  explicit peers
* Resource requests and limits on every container
* Liveness, readiness and startup probes
* PodDisruptionBudget
* HorizontalPodAutoscaler example
* External Secrets Operator
* kube-prometheus-stack or equivalent, plus OpenTelemetry collector
* Admission policy (Kyverno or OPA Gatekeeper) for the checks CI might
  miss: latest tags, missing limits, hostNetwork

Argo CD is the deployer. Helm is the package. Kustomize overlays adjust
provider specifics.

## Workload identity

| Cluster | Mechanism |
| --- | --- |
| EKS | IRSA (`eks.amazonaws.com/role-arn`) |
| AKS | Azure Workload Identity (`azure.workload.identity/client-id`) |
| GKE | Workload Identity (`iam.gke.io/gcp-service-account`) |

The application code reads environment variables and native SDKs. It does
not know which annotation put the identity there.

## Service mesh

Not in the initial platform.

A mesh is justified when you have a real need for mTLS between many
services, sophisticated L7 traffic shifting, or a uniform policy point
that NetworkPolicy cannot express. It is not justified because a
conference talk used Istio.

Cost: extra data plane, extra upgrades, extra failure mode (sidecar
cannot start, so the app cannot start), extra people. If you cannot staff
the mesh, you do not have a mesh. You have a future incident.

## Autoscaling and disruption

* HPA on CPU or a request-rate metric, not on hope
* PDB `minAvailable: 1` for two replicas; prod should run at least two
* Cluster autoscaler / node autoprovisioning is a platform concern
* Do not set CPU limits equal to requests on latency-sensitive services
  without measuring throttling. The golden path still sets both; the
  hatch is to drop the limit with a documented reason.

## Multi-tenancy

Soft multi-tenancy (namespaces, quotas, network policy) is the default.
Hard multi-tenancy (separate clusters per team) is for noisy neighbours,
compliance boundaries or very different upgrade cadences. Clusters are
not free. Neither are namespace escapes.

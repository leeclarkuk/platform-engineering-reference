# GitOps

Argo CD reconciles cluster state from this tree. CI builds images and
writes the image tag under `gitops/environments/<env>/values.yaml`.
CI does not kubectl apply application resources.

```text
gitops/bootstrap     first Application (app of apps)
gitops/applications  one Application per workload plus platform add-ons
gitops/argocd        AppProject and install notes
gitops/platform      External Secrets store, Cluster Autoscaler SA
gitops/environments  Helm values per environment, including image tags
```

Replace the example repoURL and ECR registry before using this against a
cluster. Automated prune is off on purpose.

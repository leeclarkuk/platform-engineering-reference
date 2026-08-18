# GitOps

Argo CD reconciles cluster state from this tree. CI builds images and
opens or writes a Git change for the tag. CI does not kubectl.

```text
gitops/bootstrap     first Application (app of apps)
gitops/applications  one Application per workload
gitops/argocd        later: SSO, RBAC, notifications
gitops/environments  non-secret values per env
```

Replace the example repoURL before using this against a cluster.

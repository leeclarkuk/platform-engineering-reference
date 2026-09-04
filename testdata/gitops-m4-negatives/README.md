# Milestone 4 named negative fixtures

Twenty named behaviours from the approved Milestone 4 specification.
Each directory is a committed executable fixture. `make gitops-validate`
fails if any of these exits 0.

| Dir | Behaviour |
| --- | --- |
| cluster-resource-whitelist | Any clusterResourceWhitelist (either AppProject) |
| wildcard-permission | Any wildcard permission (sourceRepos/dest/ns/resource) |
| workload-app-on-bootstrap | Workload Application assigned to bootstrap |
| root-app-on-platform | Root Application assigned to platform |
| wrong-repo-or-revision | Wrong repoURL or targetRevision |
| wrong-source-path | Wrong source path / path outside templates |
| destination-argocd-or-unlisted | Destination argocd, wildcard dest, or unlisted ns |
| automated-sync | Automated sync/prune/selfHeal on either Application |
| extra-platform-application | More than one platform workload Application |
| cluster-scoped-helm-output | Cluster-scoped Helm output |
| helm-resources-outside-apps | Rendered resources outside ns apps |
| missing-serviceaccount-sample | Missing or renamed ServiceAccount apps/sample |
| deployment-wrong-sa | Deployment not using ServiceAccount sample |
| raw-workload-under-gitops-apps | Raw workload duplication under gitops/apps |
| malformed-application-or-helm | Malformed Application or Helm output |
| missing-helm-pin-or-schema | Missing Helm pin, local schema, or recorded hash |
| stale-schema-hash | Modified vendored schema with stale hash |
| iam-or-terraform-under-gitops | IAM or Terraform under gitops |
| k8s-helm-under-terraform | K8s/Helm providers/resources under Terraform |
| live-mutation-in-validation | Live kubectl/Helm install/Argo sync/Terraform apply/AWS mutation path |

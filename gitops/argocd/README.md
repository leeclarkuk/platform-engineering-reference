# Argo CD

Install the upstream manifest into the `argocd` namespace, apply
`project.yaml`, then `../bootstrap/root-app.yaml`. Do not vendor the
full upstream install YAML in this repository; it goes stale immediately.

```bash
scripts/aws/bootstrap-argocd.sh
```

Automated sync heals drift. Prune is off. Enabling prune means a Git
delete removes the live object. Do that only when you intend destruction.

SSO, RBAC and ApplicationSets belong here in a later increment. Until
then Argo CD admin is a break-glass identity, not a team chat bot.

The intended path is Git to Argo CD to Helm to Kubernetes. GitHub Actions
does not kubectl apply application resources.

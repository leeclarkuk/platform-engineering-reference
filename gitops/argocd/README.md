# Argo CD

Install the upstream HA manifest (or the Helm chart) into the `argocd`
namespace, then apply `../bootstrap`. Do not vendor the full upstream
install YAML in this repository; it goes stale immediately.

SSO, RBAC and AppProjects belong here in a later increment. Until then
Argo CD admin is a break-glass identity, not a team chat bot.

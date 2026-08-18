# AWS operations

## Control plane access

The cluster API is private by default. GitOps runs inside the VPC. Humans
and Terraform's Kubernetes provider need a path:

* SSM Session Manager onto a node, then `kubectl` via the private endpoint
* VPN or Direct Connect into the hub, later
* Non-production only: `endpoint_public_access = true` with an explicit
  CIDR list

Do not open `0.0.0.0/0` on the public endpoint in production.

## GitOps

Argo CD owns application resources. GitHub Actions must not
`kubectl apply` the sample service. Image tags are written to
`gitops/environments/<env>/values.yaml`.

Automated prune is off. Enabling it means a Git delete removes the live
object.

## Secrets

System of record: AWS Secrets Manager `/sample-service/example-config`.
External Secrets Operator copies `EXAMPLE_CONFIG` into the namespace.
The placeholder `set-externally` is not a credential. Rotate with
`put-secret-value`. Terraform ignores later changes to the secret
string.

## Observability

Scrape `/metrics`. Recording rules in
`observability/prometheus/rules/sample-service.yaml` feed the example
SLO (99.9 percent availability, p95 under 300ms). Those numbers are
demonstration targets.

Alerts: high error rate, readiness failure, excessive latency. Install
kube-prometheus-stack yourself; this repository does not vendor it.

## Failure lab

```bash
make failure-test TEST=pod-delete
make failure-test TEST=bad-deployment
make failure-test TEST=network-policy
make failure-test TEST=node-loss
```

`node-loss` cordons and drains. Terminating the EC2 instance requires
`CONFIRM=yes AWS_TERMINATE=yes`. Do not run that in production.

Network policy tests fight Argo CD self-heal. Pause sync on
`sample-service` before replacing the allow policy, then restore it.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| Nodes `NotReady`, image pull errors | Missing ECR/S3/ECR API endpoints, or NAT missing for a non-AWS registry |
| Argo CD cannot clone Git | No NAT (or no hub egress). AWS endpoints do not reach github.com |
| Pods cannot read the example secret | External Secrets operator not installed, or Pod Identity association missing |
| `terraform apply` in the wrong account | `allowed_account_ids` tripped. Check AWS_PROFILE |
| Cross-account attachment stuck pending | RAM share not accepted, or `auto_accept_shared_attachments` is disable |

## Status language

Use the matrix in the root README. Terraform existing is not
production-ready. Local validate is not a live prove.

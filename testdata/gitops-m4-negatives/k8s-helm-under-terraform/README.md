Named M4 negative 19. Executed as
`scripts/check-aws-foundations-boundaries.sh testdata/gitops-m4-negatives/k8s-helm-under-terraform`.
This directory is the fixture the gate runs. It is not a redirect to the
Milestone 2 suite under `testdata/aws-foundations-boundaries/kubernetes` or
`testdata/aws-foundations-boundaries/helm`. The committed files include
`provider "kubernetes"` and `resource "helm_release"` so that scan covers
Kubernetes and Helm under Terraform.

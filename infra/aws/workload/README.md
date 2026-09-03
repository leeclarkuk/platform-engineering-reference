# infra/aws/workload (Milestone 2)

Workload root owns:
* `aws_eks_cluster`
* supporting AWS IAM resources
* `aws_eks_addon` for `eks-pod-identity-agent`
* `aws_eks_pod_identity_association`

Hard constraints in Milestone 2:

* No worker nodes, no node pools, no pods.
* Pod Identity is declared, but non-operational until compatible compute
  exists and schedules pods that match the declared service account
  strings.

Pod Identity role trust principal:
* `pods.eks.amazonaws.com`

ServiceAccount namespace/name input strings:
* `apps/sample`

Provenance:
* Copied from the Milestone 1 WorkloadContract fixture
  `testdata/workloadcontract-valid.yaml` where:
  * `spec.serviceAccount.namespace` is `apps`
  * `spec.serviceAccount.name` is `sample`

pstack: aws/m2-foundations


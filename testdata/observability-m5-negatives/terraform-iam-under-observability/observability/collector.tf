resource "aws_iam_role" "collector" {
  name = "sample-collector"
}
resource "helm_release" "kube_prometheus" {
  name = "kube-prometheus"
}

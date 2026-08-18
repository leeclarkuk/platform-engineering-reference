# Insecure fixture

This tree is a known-bad example. `scripts/test-policy.sh` copies it
elsewhere and asserts Checkov fails. Never apply it.

It currently proves rejection of:

* a public S3 bucket
* a wildcard IAM policy
* a security group that exposes SSH to the world
* a privileged Kubernetes pod

# Policy as code

The live Terraform tree is scanned by Checkov in CI. The `fixtures/`
directory exists to prove the scanner still has teeth.

`scripts/test-policy.sh` fails the build if the insecure S3 fixture is
accepted, or if the secure fixture is rejected.

Do not apply anything under `fixtures/insecure`.

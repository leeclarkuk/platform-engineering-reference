# Scripts

`lint.sh`, `validate.sh`, `security.sh`, `test-policy.sh` are the Make
backends. They must work without cloud credentials. Do not add apply
or destroy here.

AWS-specific static checks live in `scripts/aws/`. Failure-lab runners
live in `scripts/failure-lab/` and require a kubeconfig for injection.

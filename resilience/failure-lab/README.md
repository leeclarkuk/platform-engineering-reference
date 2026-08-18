# Failure lab

A control plane reporting healthy does not prove that real application
traffic is healthy. This lab is how we test the user path.

Automated runners:

```bash
make failure-test TEST=pod-delete
make failure-test TEST=bad-deployment
make failure-test TEST=network-policy
make failure-test TEST=node-loss
```

Those require kubeconfig. They do not require AWS API calls except
`TEST=node-loss CONFIRM=yes AWS_TERMINATE=yes`.

Write-ups in `experiments/` still exist for game days. Fill **Observed**
and **MTTR** when you run them. Do not invent those numbers in Git.

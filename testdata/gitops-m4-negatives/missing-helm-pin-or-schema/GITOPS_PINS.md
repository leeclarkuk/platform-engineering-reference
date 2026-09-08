# Incomplete pins for the missing Helm pin negative fixture.

The gate reads the machine-readable fence only. Helm pin keys are
omitted so `verify_committed_schemas` fails as a missing Helm pin.

```
kustomize_version: 5.8.1
kubeconform_version: 0.8.0
kubernetes_schema_version: 1.33.4
```

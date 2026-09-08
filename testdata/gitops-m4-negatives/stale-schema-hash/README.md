# stale-schema-hash

Hash-only negative, same shape as
`testdata/observability-m5-negatives/stale-hash/`. The pin fence records
one wrong SHA-256 (`kubernetes_namespace_schema_sha256` is all zeros).
Tiny stubs sit at the six schema paths `verify_committed_schemas` reads,
so the failure is a hash mismatch rather than a missing file.

This directory does not vendor the living `gitops/schemas/` tree. Do not
copy those JSON files here. The GitOps validate script is unchanged: the
current checker returns on the first hash mismatch.

Named reason: schema hash mismatch.

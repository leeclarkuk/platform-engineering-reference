# Kubernetes security

Golden-path namespaces enforce Pod Security Standards `restricted`.
NetworkPolicy is default-deny-ish: DNS and 443 out, service port in.
Admission policies (Kyverno) land in a later increment; until then CI
and PSS are the gates.

Do not run privileged workloads on the golden path. Vendor CNI or node
agents that require privilege live in a platform namespace with an
explicit exception.

# Supply chain

CI for application repos should:

1. Run tests
2. Scan dependencies (`govulncheck`, Trivy fs)
3. Build a pinned image
4. Generate an SBOM (Syft)
5. Sign the image (Cosign, keyless OIDC)
6. Scan the image (Trivy)
7. Push to the private registry
8. Update GitOps with the digest, not `:latest`

This repository demonstrates steps 1-3 and 6 on itself. Signing and SBOM
publish need a registry and OIDC. See `docs/security/oidc.md`.

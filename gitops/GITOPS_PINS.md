# GitOps pins (Milestone 3)

pstack: gitops/m3-bootstrap

These pins were recorded from published checksum files and from SHA-256
hashes of the downloaded archives, extracted binaries, and vendored JSON
schema files. They were not invented. Tool installation may use the
network. `make gitops-validate` then validates only from committed files
and local schema paths. Remote schema locations are not configured.

## Machine-readable pins

```
kustomize_version: 5.8.1
kustomize_git_commit: 9790a1c3efd2fd35f1b768d495112834176581c1
kustomize_archive: kustomize_v5.8.1_linux_amd64.tar.gz
kustomize_archive_url: https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.8.1/kustomize_v5.8.1_linux_amd64.tar.gz
kustomize_archive_sha256: 029a7f0f4e1932c52a0476cf02a0fd855c0bb85694b82c338fc648dcb53a819d
kustomize_binary_sha256_linux_amd64: f7b1605aa5143e0dcbd754a4d43c47ad7a560c540b1356b064d69fe236164494
kubeconform_version: 0.8.0
kubeconform_git_commit: 02374e583d700721f57300fae78e11acd27ee539
kubeconform_archive: kubeconform-linux-amd64.tar.gz
kubeconform_archive_url: https://github.com/yannh/kubeconform/releases/download/v0.8.0/kubeconform-linux-amd64.tar.gz
kubeconform_archive_sha256: 9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883
kubeconform_binary_sha256_linux_amd64: 457722b36e98d7bdbc91525e594951ef5d7ea3a29da2d13b9b28a2fb8a5097b7
kubernetes_schema_version: 1.33.4
kubernetes_schema_source: yannh/kubernetes-json-schema
kubernetes_schema_commit: 229f0f08ac8675814210a2981f45363438a43930
kubernetes_namespace_schema_sha256: 324fae677b98d1a6d54340db0c334d053e8ffbafceb3f73326e41de2610d5843
argocd_schema_version: 3.5.0
argocd_schema_source: datreeio/CRDs-catalog
argocd_schema_commit: 5cf8adaf773374bd153ba7e0fd37d8fc955e750c
argocd_application_schema_sha256: 99c37877b0626eaf21f42f70f4fc432a4b820de548d88ed90cc75381adf5192c
argocd_appproject_schema_sha256: 5b3f7b75f59e5821d06cedc6b0667b3f5a0d5efd2c9b6cb606cd4da40755a121
actions_checkout_sha: 3d3c42e5aac5ba805825da76410c181273ba90b1
actions_setup_go_sha: b7ad1dad31e06c5925ef5d2fc7ad053ef454303e
actions_setup_terraform_sha: dfe3c3f87815947d99a8997f908cb6525fc44e9e
```

## kustomize

* Version: `5.8.1`
* Git commit: `9790a1c3efd2fd35f1b768d495112834176581c1` (peeled from annotated tag `kustomize/v5.8.1`)
* Linux amd64 archive SHA-256 (from the release `checksums.txt`): `029a7f0f4e1932c52a0476cf02a0fd855c0bb85694b82c338fc648dcb53a819d`
* Extracted linux amd64 binary SHA-256 (computed after checksum verification): `f7b1605aa5143e0dcbd754a4d43c47ad7a560c540b1356b064d69fe236164494`

## kubeconform

* Version: `0.8.0`
* Git commit: `02374e583d700721f57300fae78e11acd27ee539` (tag `v0.8.0`)
* Linux amd64 archive SHA-256 (from the release `CHECKSUMS` file): `9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883`
* Extracted linux amd64 binary SHA-256 (computed after checksum verification): `457722b36e98d7bdbc91525e594951ef5d7ea3a29da2d13b9b28a2fb8a5097b7`

## Kubernetes JSON schemas

* Schema version: `1.33.4` (`-kubernetes-version 1.33.4`)
* Layout: `gitops/schemas/kubernetes/v1.33.4-standalone-strict/`, usable directly by kubeconform
* Source repository: `yannh/kubernetes-json-schema`
* Source commit for `v1.33.4-standalone-strict/namespace-v1.json`: `229f0f08ac8675814210a2981f45363438a43930`
* Vendored file SHA-256: `324fae677b98d1a6d54340db0c334d053e8ffbafceb3f73326e41de2610d5843`

Milestone 3 only renders Namespace from core Kubernetes. The gate fails closed if this directory is missing or contains no JSON files, and kubeconform is not given `--ignore-missing-schemas`.

## Argo CD JSON schemas

* Schema version: Argo CD `3.5.0` CRDs
* Layout: `gitops/schemas/argocd/argoproj.io/{application,appproject}_v1alpha1.json`, usable directly by kubeconform (`{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json`)
* Source repository: `datreeio/CRDs-catalog`
* Source commit: `5cf8adaf773374bd153ba7e0fd37d8fc955e750c` (commit message records Argo CD 3.5.0 CRDs)
* `application_v1alpha1.json` SHA-256: `99c37877b0626eaf21f42f70f4fc432a4b820de548d88ed90cc75381adf5192c`
* `appproject_v1alpha1.json` SHA-256: `5b3f7b75f59e5821d06cedc6b0667b3f5a0d5efd2c9b6cb606cd4da40755a121`

## GitHub Actions (unchanged in this milestone)

These SHAs are the pins already present in `.github/workflows/ci.yml`. Milestone 3 does not add an Action and does not change them. Terraform CLI/action pins stay in `infra/aws/TERRAFORM_PINS.md`.

* `actions/checkout` v7.0.1: `3d3c42e5aac5ba805825da76410c181273ba90b1`
* `actions/setup-go` v7.0.0: `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e`
* `hashicorp/setup-terraform` v4.0.1: `dfe3c3f87815947d99a8997f908cb6525fc44e9e`

CI Go remains `1.22.12`. `persist-credentials: false` remains. This workflow does not grant `actions: write`.

## Limitations (evidence)

* Integrity evidence here is published SHA-256 checksums plus locally computed SHA-256 of extracted binaries and vendored schema files.
* GPG or SLSA provenance of kustomize and kubeconform is not recorded, so it is not proved.
* Argo CD JSON schemas are the CRDs-catalog conversion of Argo CD 3.5.0 CRDs. They are not a live Argo CD install and not Argo CD 3.5.2 (the latest tag at pin time).
* Tool installation may use the network. Validation after install uses only committed schemas and local `-schema-location` paths. Remote schema URLs are not configured in the gate.

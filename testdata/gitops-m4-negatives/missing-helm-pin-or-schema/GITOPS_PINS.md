# GitOps pins (Milestone 3 and Milestone 4)

pstack: gitops/m4-workload-application

These pins were recorded from published checksum files and from SHA-256
hashes of the downloaded archives, extracted binaries, and vendored JSON
schema files. They were not invented. Tool installation may use the
network. `make gitops-validate` then validates only from committed files
and local schema paths. Remote schema locations are not configured.
Helm is invoked as `lint` and `template` only. No chart repository is
configured.

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
kubernetes_namespace_schema_path: gitops/schemas/kubernetes/v1.33.4-standalone-strict/namespace-v1.json
kubernetes_namespace_schema_sha256: 324fae677b98d1a6d54340db0c334d053e8ffbafceb3f73326e41de2610d5843
kubernetes_deployment_schema_path: gitops/schemas/kubernetes/v1.33.4-standalone-strict/deployment-apps-v1.json
kubernetes_deployment_schema_sha256: 8a4163cd36194edf94abdedff96b5bd8f612f76818a2a3767b35d1c72b8a7868
kubernetes_service_schema_path: gitops/schemas/kubernetes/v1.33.4-standalone-strict/service-v1.json
kubernetes_service_schema_sha256: 8bf019854daed511e7c174896a898173fa65d88ec5937c687a37303d4cc9351b
kubernetes_serviceaccount_schema_path: gitops/schemas/kubernetes/v1.33.4-standalone-strict/serviceaccount-v1.json
kubernetes_serviceaccount_schema_sha256: 8193d6c3561475c6d3d5c44e1faedb1df53905373d904bc17015694326d659cf
argocd_schema_version: 3.5.0
argocd_schema_source: datreeio/CRDs-catalog
argocd_schema_commit: 5cf8adaf773374bd153ba7e0fd37d8fc955e750c
argocd_application_schema_path: gitops/schemas/argocd/argoproj.io/application_v1alpha1.json
argocd_application_schema_sha256: 99c37877b0626eaf21f42f70f4fc432a4b820de548d88ed90cc75381adf5192c
argocd_appproject_schema_path: gitops/schemas/argocd/argoproj.io/appproject_v1alpha1.json
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

## Helm

* Version: `3.21.4`
* Git commit: `813176c51bb5c181dbbd7901298ddcc104cd3417` (peeled from annotated tag `v3.21.4`; matches `helm version` GitCommit)
* Linux amd64 archive SHA-256 (from https://get.helm.sh/helm-v3.21.4-linux-amd64.tar.gz.sha256sum): `61f88ab166748cb19604d7884cb100ae9ccb13804ddeb98e08af167eacbb6a14`
* Extracted linux amd64 binary SHA-256 (computed after checksum verification): `cd27ec335b9c961a0a098cce870fded88429210edc898fd213da0b16e67333bd`

`make gitops-validate` installs this exact archive, then runs `helm lint templates/` and `helm template sample templates` with no `--set`, no chart repository, and no `helm install` / `helm upgrade`.

## Kubernetes JSON schemas

* Schema version: `1.33.4` (`-kubernetes-version 1.33.4`)
* Layout: `gitops/schemas/kubernetes/v1.33.4-standalone-strict/`, usable directly by kubeconform
* Source repository: `yannh/kubernetes-json-schema`
* Source commit: `229f0f08ac8675814210a2981f45363438a43930`
* `namespace-v1.json` SHA-256: `324fae677b98d1a6d54340db0c334d053e8ffbafceb3f73326e41de2610d5843`
* `deployment-apps-v1.json` SHA-256: `8a4163cd36194edf94abdedff96b5bd8f612f76818a2a3767b35d1c72b8a7868`
* `service-v1.json` SHA-256: `8bf019854daed511e7c174896a898173fa65d88ec5937c687a37303d4cc9351b`
* `serviceaccount-v1.json` SHA-256: `8193d6c3561475c6d3d5c44e1faedb1df53905373d904bc17015694326d659cf`

Milestone 3 renders Namespace. Milestone 4 also kubeconforms Helm-rendered Deployment, Service, and ServiceAccount. `make gitops-validate` checks these exact paths and SHA-256 values. Drift fails the gate. kubeconform is not given `--ignore-missing-schemas`.

## Argo CD JSON schemas

* Schema version: Argo CD `3.5.0` CRDs
* Layout: `gitops/schemas/argocd/argoproj.io/{application,appproject}_v1alpha1.json`, usable directly by kubeconform (`{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json`)
* Source repository: `datreeio/CRDs-catalog`
* Source commit: `5cf8adaf773374bd153ba7e0fd37d8fc955e750c` (commit message records Argo CD 3.5.0 CRDs)
* `application_v1alpha1.json` SHA-256: `99c37877b0626eaf21f42f70f4fc432a4b820de548d88ed90cc75381adf5192c`
* `appproject_v1alpha1.json` SHA-256: `5b3f7b75f59e5821d06cedc6b0667b3f5a0d5efd2c9b6cb606cd4da40755a121`

`make gitops-validate` checks both exact paths and SHA-256 values. Drift of
the Application schema hash fails CI.

## GitHub Actions (unchanged in this milestone)

These SHAs are the pins already present in `.github/workflows/ci.yml`. Milestone 4 does not add an Action and does not change them. Terraform CLI/action pins stay in `infra/aws/TERRAFORM_PINS.md`.

* `actions/checkout` v7.0.1: `3d3c42e5aac5ba805825da76410c181273ba90b1`
* `actions/setup-go` v7.0.0: `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e`
* `hashicorp/setup-terraform` v4.0.1: `dfe3c3f87815947d99a8997f908cb6525fc44e9e`

CI Go remains `1.22.12`. `persist-credentials: false` remains. This workflow does not grant `actions: write`.

## Limitations (evidence)

* Integrity evidence here is published SHA-256 checksums plus locally computed SHA-256 of extracted binaries and vendored schema files.
* GPG or SLSA provenance of kustomize, kubeconform, and Helm is not recorded, so it is not proved.
* Argo CD JSON schemas are the CRDs-catalog conversion of Argo CD 3.5.0 CRDs. They are not a live Argo CD install and not Argo CD 3.5.2 (the latest tag at pin time).
* Tool installation may use the network. Validation after install uses only committed schemas and local `-schema-location` paths. Remote schema URLs are not configured in the gate.
* Helm `lint` / `template` prove chart syntax and local render only. They do not prove a live Argo CD sync, a running workload, or operational Pod Identity.

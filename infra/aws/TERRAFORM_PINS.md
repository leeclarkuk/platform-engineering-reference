# Milestone 2 Terraform pins and evidence

pstack: aws/m2-foundations

## Terraform CLI

* Terraform version: `1.16.1`
* Install checksum (SHA-256): `745d33b4b02b7980c62a38ec1beea24ee084ea8caf3f503c200554bd9a0cbe49`
* Source: `https://releases.hashicorp.com/terraform/1.16.1/`

The Terraform configuration in each root sets:
`terraform.required_version = "= 1.16.1"`.

## GitHub Actions setup-terraform pin (CI)

* Action: `hashicorp/setup-terraform`
* Tag: `v4.0.1`
* Pinned commit SHA: `dfe3c3f87815947d99a8997f908cb6525fc44e9e`

## Limitations (evidence)

* Evidence recorded here includes SHA-256 checksum matching for the Terraform
  CLI binary.
* Signature or provenance verification (for example, GPG/SLSA attestations)
  is not recorded in this repository, so it is not proved.
* `terraform init -backend=false` still downloads the locked AWS provider.
  "No AWS credentials" is not an air-gapped init.


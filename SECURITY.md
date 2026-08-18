# Security policy

## Supported versions

This repository is a reference architecture, not a hosted product. Security
fixes are applied to `main`. There are no versioned releases yet.

## What this project treats as a vulnerability

Report anything that would let an adopter:

* deploy with standing cloud credentials
* expose secrets in Git, CI logs or Terraform state
* bypass admission policy or network policy defaults
* run privileged workloads from the golden path
* publish unsigned or unscanned images into a cluster

Do not report theoretical issues that only exist if an adopter ignores the
documented guardrails. Do report cases where the defaults themselves are
unsafe.

## Reporting a vulnerability

Do not open a public issue for security reports.

Email: security@example.com (replace this address before using the repository
in anger). Include:

* a description of the issue
* affected paths
* reproduction steps that do not require production credentials
* the impact if exploited

You should receive an acknowledgement within five working days.

## Secret handling in this repository

* Cloud authentication is via short-lived OIDC federation. See
  `docs/security/oidc.md`.
* No long-lived access keys belong in GitHub Actions secrets.
* Terraform state is local in this reference so validation does not need a
  backend. Real deployments must use a locked remote backend with encryption
  and restricted IAM.
* The directory `security/policy-as-code/fixtures/insecure` contains
  deliberately failing examples. They exist to prove scanners reject bad
  configuration. They must never be applied.

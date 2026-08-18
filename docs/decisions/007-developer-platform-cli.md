# ADR-007: Developer platform CLI

- Status: Accepted
- Date: 2026-08-18

## Context

Golden paths die when they are a Confluence page. Teams copy the last
service they found, including the mistakes. We need a supported way to
create a service that already looks like the platform.

## Options considered

1. **Small Go CLI** (`platform create service`). Versioned with the repo,
   testable, no extra runtime.
2. **Cookiecutter / copier templates only.** Lowest build cost, drift as
   soon as templates evolve.
3. **Backstage (or similar) software templates.** Better catalogue and
   ownership UI, much larger operational surface.
4. **Do nothing.** Publish examples and hope.

## Decision

Ship a small Go CLI as the first interface. Templates live in this
repository. A developer portal is a later product decision (ADR-009), not a
prerequisite for a golden path.

## Rationale

The command `platform create service payments-api` is the contract. Whether
that command is invoked from a terminal, a Backstage action or a ChatOps bot
does not change the contract. Building the portal first is how platforms
spend a year on a catalogue of services that do not exist.

Go matches the sample service language, produces a single binary and is
boring to distribute. Python would be fine. Node would add a runtime to a
tool that should not have one.

## Trade-offs

* A CLI without a catalogue will not solve discovery or ownership on its
  own. We still need a service catalogue later, even if it starts as YAML.
* Template updates do not rewrite existing services. Version the templates
  and publish migration notes. Do not auto-PR hundreds of repos from day one.
* Windows engineers will need a binary. CI builds it. We do not maintain
  an installer ecosystem yet.

## Consequences

* Commands in the first release: `version`, `doctor`, `create service`,
  `validate`.
* The CLI must not require cloud credentials for those commands.
* `doctor` checks local tools and repository conventions, not live clusters.

## When we would reconsider

* Adopting a portal whose template engine should own scaffolding.
* A language-specific decision if the organisation standardises on .NET or
  Python exclusively. The CLI can still be Go even then.

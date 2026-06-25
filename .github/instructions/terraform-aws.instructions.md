---
applyTo: "aws/**/*.tf"
description: "Terraform AWS conventions for provider/version handling, dependency safety, and path-sensitive behavior in this repository."
---

# Terraform AWS Instructions

Apply these rules when editing Terraform files under aws/.

## Scope
- This directory owns infrastructure lifecycle, provider configuration, TLS material generation, and environment export output.
- Keep edits in aws/ focused on infrastructure concerns only.

## Provider And Version Handling
- Keep required providers centralized in aws/providers.tf.
- Preserve explicit provider source and version constraints when changing provider blocks.
- Do not widen version constraints casually; prefer conservative updates and keep compatibility with existing syntax and resources.
- Keep terraform.required_version compatible with the rest of the configuration and avoid introducing language features that conflict with it.
- Do not duplicate provider version constraints across multiple files unless there is a clear reason.

## Path-Sensitive Behavior
- Run Terraform commands from aws/ so relative paths and generated artifacts resolve correctly.
- Preserve path-sensitive values unless explicitly requested:
  - datacenter.env is generated in aws/ (local_file filename).
  - cert references rely on ${path.cwd}/certs/datacenter_ca.cert.
- Avoid replacing path.cwd with path.module unless you have verified downstream shell workflows still work.
- Preserve output shape that users and scripts rely on (for example source ./datacenter.env).

## Dependency Safety
- Treat aws_instance.server[0], TLS resources, and generated tokens as foundational dependencies for Consul/Nomad providers.
- Avoid introducing dependency cycles between provider configuration and resources.
- Do not hardcode secrets or tokens; keep generated/sensitive values marked and handled as sensitive outputs when applicable.

## Variable And Interface Stability
- Prefer variable-driven configuration over hardcoded constants.
- When adding or changing variables, update descriptions and defaults carefully.
- Keep behavior aligned with aws/variables.hcl and aws/variables.hcl.example expectations.

## Validation And Formatting
- After terraform changes, run from aws/:
  - terraform fmt -recursive
  - terraform validate
- If provider or variable interface changes, verify README and AGENTS guidance remains accurate.

## Avoid These Regressions
- Breaking Consul/Nomad TLS environment variable expectations.
- Changing working-directory assumptions for Terraform apply/destroy workflows.
- Removing or weakening sensitive handling for token outputs.

---
applyTo: "shared/jobs/*.nomad.hcl"
description: "Nomad job-spec conventions and safe edit rules for staged HashiCups deployment jobs."
---

# Nomad Job Spec Instructions

Use these rules when editing files in `shared/jobs/*.nomad.hcl`.

## Scope And Intent
- Preserve the staged learning flow from `01` to `05`; each file represents a deliberate architecture step.
- Keep behavior changes minimal and stage-appropriate unless the task explicitly requests cross-stage refactoring.
- Treat API gateway and autoscaler jobs as separate concerns from the main `hashicups` job.

## Required Safety Rules
- Do not rename existing jobs, groups, services, or task names unless explicitly requested.
- Do not change the API gateway namespace semantics: `api-gateway` runs in Nomad namespace `ingress`.
- Do not remove or weaken placement constraints tied to `meta.nodeRole` without an explicit requirement.
- Do not switch service discovery mode accidentally:
  - Early stages use direct addresses/Consul DNS.
  - Mesh stages (`04`/`05`) use `connect` sidecars and localhost/upstreams.
- Do not remove health checks, `service` blocks, or `provider = "consul"` from services unless explicitly requested.
- Keep externally exposed ports stable unless the request is specifically about port changes (`80` in early nginx stage, `8443` for API gateway).

## Editing Conventions
- Prefer variable-driven values over hard-coded literals for versions, ports, and scale limits.
- If adding variables, include `description`, `type` when appropriate, and safe defaults.
- Keep existing HCL style and comment structure.
- Keep task `driver` choices consistent with current design (`docker` vs `raw_exec`) unless a migration is requested.
- For connect-enabled services, preserve upstream wiring and local bind assumptions.

## Validation Expectations
- Validate every changed Nomad job file from `shared/jobs/` with:
  - `nomad job validate <filename>`
- If a change affects gateway or autoscaling, validate related files as well (`04.api-gateway.nomad.hcl`, `05.autoscaler.nomad.hcl`, `05.hashicups.nomad.hcl`).

## Cross-File Awareness
- If a change requires Consul config or intentions updates, also review matching helper scripts:
  - `04.api-gateway.config.sh`
  - `04.intentions.consul.sh`
  - `05.autoscaler.config.sh`
- Keep instruction-level guidance concise and link to canonical docs for detailed workflow:
  - `README.md`
  - `AGENTS.md`

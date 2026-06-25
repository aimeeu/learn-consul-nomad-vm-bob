---
name: run-lab-workflow
description: "Automate repeatable Consul/Nomad lab workflows: AMI build, Terraform apply, environment setup, stage deployment, validation, and cleanup for this repository."
---

# Run Lab Workflow

Use this skill to execute repeatable operational workflows in this repository with consistent checks and command ordering.

## When To Use
- Build AMI and provision infrastructure for the lab.
- Deploy a specific HashiCups stage (01 to 05).
- Validate Terraform or Nomad job specs.
- Perform cleanup in the correct order.

## Required Inputs
Collect missing inputs before running commands:
- Workflow mode: build-ami, provision, deploy-stage, validate, cleanup, full
- Stage number when mode is deploy-stage or full (01 to 05)
- AWS region and AMI value expectations for variables.hcl
- Whether infrastructure already exists

## Global Preflight
1. Verify required CLIs are present: packer, terraform, nomad, consul, aws, openssl, hey.
2. Confirm working directories exist: aws/, shared/jobs/, shared/scripts/.
3. Confirm AWS credentials are configured in the shell environment.

## Mode: build-ami
From aws/:
1. Ensure variables.hcl exists (copy from variables.hcl.example if missing).
2. packer init image.pkr.hcl
3. packer build -var-file=variables.hcl image.pkr.hcl
4. Ask user to confirm AMI ID update in variables.hcl.

## Mode: provision
From aws/:
1. export CONSUL_TLS_SERVER_NAME=consul.dc1.global (or derived from datacenter/domain values)
2. terraform init
3. terraform apply -var-file=variables.hcl
4. source ./datacenter.env

## Mode: deploy-stage
From shared/jobs/:
- Stage 01: nomad job run 01.hashicups.nomad.hcl
- Stage 02: nomad job run 02.hashicups.nomad.hcl
- Stage 03: nomad job run 03.hashicups.nomad.hcl
- Stage 04:
  1. ./04.api-gateway.config.sh
  2. ./04.intentions.consul.sh
  3. nomad job run 04.api-gateway.nomad.hcl
  4. nomad job run 04.hashicups.nomad.hcl
- Stage 05:
  1. ./05.autoscaler.config.sh
  2. nomad job run 05.autoscaler.nomad.hcl
  3. nomad job run 05.hashicups.nomad.hcl

## Mode: validate
From aws/:
- terraform fmt -recursive
- terraform validate

From shared/jobs/:
- nomad job validate 01.hashicups.nomad.hcl
- nomad job validate 02.hashicups.nomad.hcl
- nomad job validate 03.hashicups.nomad.hcl
- nomad job validate 04.api-gateway.nomad.hcl
- nomad job validate 04.hashicups.nomad.hcl
- nomad job validate 05.autoscaler.nomad.hcl
- nomad job validate 05.hashicups.nomad.hcl

## Mode: cleanup
From shared/jobs/:
1. nomad job stop -purge hashicups autoscaler
2. nomad job stop -purge --namespace ingress api-gateway

From aws/:
3. source ../shared/scripts/unset_env_variables.sh
4. terraform destroy -var-file=variables.hcl (only when explicitly requested)

## Mode: full
1. Run build-ami.
2. Run provision.
3. Run deploy-stage for selected stage.
4. Run validate.
5. Optionally run cleanup if user explicitly requests teardown.

## Operational Rules
- Keep command execution directory-correct (aws/ vs shared/jobs/).
- Preserve stage progression semantics; do not skip required stage scripts for 04 and 05.
- Treat api-gateway as namespace ingress.
- Never perform destructive cleanup unless the user asks.
- Report command outcomes and any manual follow-up needed.

## References
- ../../../README.md
- ../../../AGENTS.md

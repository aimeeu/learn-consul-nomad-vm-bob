---
mode: agent
description: "Deploy a selected HashiCups stage with preflight checks, stage-specific actions, and post-deploy validation."
---

Deploy a HashiCups stage safely in this repository.

## Inputs
Ask for missing inputs before running commands:
- Stage: 01, 02, 03, 04, or 05
- Action: deploy or stop
- Whether infrastructure already exists (yes/no)

## Preflight
1. Verify required CLIs exist: packer, terraform, nomad, consul, aws, openssl, hey.
2. Confirm repository layout exists: aws/, shared/jobs/, shared/scripts/.
3. If infrastructure is expected to exist, ensure aws/datacenter.env exists.
4. Ensure CONSUL_TLS_SERVER_NAME is set before terraform apply when provisioning.

## Provision Infrastructure (if needed)
From aws/:
1. Ensure variables.hcl exists (create from variables.hcl.example if missing).
2. terraform init
3. terraform apply -var-file=variables.hcl
4. source ./datacenter.env

## Deploy Action
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

## Stop Action
From shared/jobs/:
- For stages 01-03: nomad job stop -purge hashicups
- For stages 04-05:
  1. nomad job stop -purge hashicups autoscaler
  2. nomad job stop -purge --namespace ingress api-gateway

## Post-Action Validation
- Run nomad job status for relevant jobs.
- For stage 04/05, confirm api-gateway namespace usage (ingress).
- Report exactly what commands were run, results, and next-step command suggestions.

## Safety Rules
- Do not change job specs during deploy unless the user explicitly asks for edits.
- Keep stage progression semantics intact (01 to 05).
- Never run terraform destroy unless explicitly requested.

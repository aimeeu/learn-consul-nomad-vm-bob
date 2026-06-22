# AGENTS

## Purpose
This repository provisions an AWS-based Consul and Nomad lab, then deploys HashiCups through staged Nomad job specs.

Primary references:
- [README](README.md)
- [AWS infrastructure](aws/)
- [Shared configs, scripts, and jobs](shared/)

## Project Layout
- aws/: Terraform and Packer for image build and infrastructure provisioning.
- shared/conf/: Consul, Nomad, Vault, and consul-template agent configuration templates copied into VM images.
- shared/data-scripts/: User-data scripts used by Terraform EC2 instances.
- shared/jobs/: Nomad job specs and helper scripts for staged HashiCups deployments.
- shared/scripts/: AMI setup and local environment cleanup helpers.

## Environment And Tooling
Required CLIs:
- packer
- terraform
- nomad
- consul
- aws
- openssl
- hey

Assume AWS credentials are already configured in the shell environment.

## Standard Workflow
1. Build AMI from aws/:
   - cp variables.hcl.example variables.hcl
   - edit region in variables.hcl
   - packer init image.pkr.hcl
   - packer build -var-file=variables.hcl image.pkr.hcl
2. Update variables.hcl with AMI ID from packer output.
3. Set CONSUL_TLS_SERVER_NAME before terraform apply:
   - export CONSUL_TLS_SERVER_NAME=consul.dc1.global
4. Provision infrastructure from aws/:
   - terraform init
   - terraform apply -var-file=variables.hcl
5. Source generated environment file from aws/:
   - source ./datacenter.env
6. Deploy Nomad jobs from shared/jobs/ in sequence:
   - 01.hashicups.nomad.hcl
   - 02.hashicups.nomad.hcl
   - 03.hashicups.nomad.hcl
   - 04.api-gateway.config.sh, 04.intentions.consul.sh, 04.api-gateway.nomad.hcl, 04.hashicups.nomad.hcl
   - 05.autoscaler.config.sh, 05.autoscaler.nomad.hcl, 05.hashicups.nomad.hcl
7. Cleanup:
   - nomad job stop -purge hashicups autoscaler
   - nomad job stop -purge --namespace ingress api-gateway
   - source ../shared/scripts/unset_env_variables.sh
   - terraform destroy -var-file=variables.hcl

## Agent Working Rules
- Prefer making infrastructure edits in aws/ only when the change is infrastructure-related.
- Prefer making runtime and service behavior edits in shared/jobs/ for Nomad behavior changes.
- Keep staged learning flow intact: 01 to 05 files represent progressive architecture changes.
- When adjusting API gateway operations, remember it runs in namespace ingress.
- For CLI instructions, keep commands runnable as-is from the directory stated in the README section.

## Validation Commands
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

## Known Pitfalls
- variables.hcl is used by both packer and terraform; do not treat it like a tfvars-only file.
- Running terraform commands outside aws/ can break relative-path assumptions for generated artifacts like datacenter.env and cert paths.
- Terraform Consul provider setup depends on TLS settings and generated cert material; preserve related outputs and file paths.
- The setup script in shared/scripts/setup.sh is image-provisioning logic for Packer builds, not a local developer bootstrap script.

# Ansible Conversion

This directory contains Ansible equivalents for the bash automation that previously lived under `shared/scripts`, `shared/data-scripts`, and `shared/jobs`.

## Playbooks

- `playbooks/setup.yml` replaces `shared/scripts/setup.sh`
- `playbooks/user-data-server.yml` replaces `shared/data-scripts/user-data-server.sh`
- `playbooks/user-data-client.yml` replaces `shared/data-scripts/user-data-client.sh`
- `playbooks/api-gateway.yml` replaces `shared/jobs/04.api-gateway.config.sh`
- `playbooks/intentions.yml` replaces `shared/jobs/04.intentions.consul.sh`
- `playbooks/autoscaler.yml` replaces `shared/jobs/05.autoscaler.config.sh`
- `playbooks/load-test.yml` replaces `shared/jobs/05.load-test.sh`
- `playbooks/unset-env.yml` documents the shell limitation for `shared/scripts/unset_env_variables.sh`

## Notes

- The environment-unset helper is the only case that cannot be fully replicated with Ansible alone because Ansible cannot modify the parent shell process.
- The playbooks are written to keep the current repo structure intact so existing Terraform and operational workflows can be migrated incrementally.

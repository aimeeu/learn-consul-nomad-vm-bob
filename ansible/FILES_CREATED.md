# Ansible Configuration Files - Complete Inventory

This document lists all files created for the Ansible-based HashiStack configuration.

## 📊 Summary

- **Total Files Created:** 20
- **Playbooks:** 3
- **Templates:** 6
- **Policy Files:** 8
- **Documentation:** 3

## 📁 File Structure

```
ansible/
├── ansible.cfg                                  # Ansible configuration
├── inventory.ini.example                        # Example inventory
├── README.md                                    # Original setup documentation
├── CONFIGURATION_README.md                      # Server/client config guide
├── FILES_CREATED.md                            # This file
│
├── Playbooks (3)
│   ├── setup-hashistack.yml                    # Install HashiStack packages
│   ├── configure-servers.yml                   # Configure Consul/Nomad servers
│   └── configure-clients.yml                   # Configure Consul/Nomad clients
│
├── templates/ (6)
│   ├── consul-server.hcl.j2                    # Consul server configuration
│   ├── consul-client.hcl.j2                    # Consul client configuration
│   ├── nomad-server.hcl.j2                     # Nomad server configuration
│   ├── nomad-client.hcl.j2                     # Nomad client configuration
│   ├── consul-server-tokens-bootstrap.hcl.j2   # Bootstrap token config
│   └── systemd-resolved-consul.conf.j2         # DNS forwarding config
│
└── policies/ (8 + README)
    ├── README.md                                # Policy documentation
    ├── policy-nomad-tasks.hcl                   # Consul ACL for Nomad tasks
    ├── jwt-auth-method-config.json              # JWT auth method config
    ├── api-gateway-certificate.hcl              # API Gateway TLS cert
    ├── api-gateway-config.hcl                   # API Gateway listener
    ├── api-gateway-http-route.hcl               # HTTP route config
    ├── intentions-database.hcl                  # Database intentions
    ├── intentions-all.hcl                       # All service intentions
    └── nomad-autoscaler-policy.hcl              # Autoscaler ACL policy
```

## 📝 Detailed File Descriptions

### Playbooks

#### 1. setup-hashistack.yml (267 lines)
**Purpose:** Install HashiStack components on all nodes  
**Source:** Converted from `shared/scripts/setup.sh`  
**Installs:**
- Consul v1.22.5
- Nomad v2.0.1
- Vault v1.21.3
- Consul Template v0.41.4
- Docker CE
- OpenJDK 8
- System utilities

**Usage:**
```bash
ansible-playbook setup-hashistack.yml
```

#### 2. configure-servers.yml (434 lines)
**Purpose:** Configure Consul and Nomad servers with full ACL setup  
**Source:** Converted from `shared/data-scripts/user-data-server.sh`  
**Features:**
- TLS certificate deployment
- Consul server with ACLs
- Nomad server with ACLs
- Workload identity integration
- DNS configuration
- ACL token generation
- Nomad ACL bootstrap
- Auth method and binding rules

**Usage:**
```bash
ansible-playbook configure-servers.yml
```

#### 3. configure-clients.yml (283 lines)
**Purpose:** Configure Consul and Nomad clients  
**Source:** Converted from `shared/data-scripts/user-data-client.sh`  
**Features:**
- TLS certificate deployment
- CNI plugins installation
- Consul client with ACLs
- Nomad client with ACLs
- DNS configuration
- Docker privileged mode
- Raw exec driver

**Usage:**
```bash
ansible-playbook configure-clients.yml
```

### Templates

#### 1. consul-server.hcl.j2 (131 lines)
**Purpose:** Consul server configuration template  
**Source:** Based on `shared/conf/agent-config-consul_server.hcl`  
**Variables:**
- `datacenter`, `domain`, `inventory_hostname`
- `server_count`, `ip_address`
- `consul_retry_join`, `consul_encryption_key`
- `consul_config_dir`

#### 2. consul-client.hcl.j2 (109 lines)
**Purpose:** Consul client configuration template  
**Source:** Based on `shared/conf/agent-config-consul_client.hcl`  
**Variables:**
- `datacenter`, `domain`, `inventory_hostname`
- `ip_address`, `docker_bridge_ip_address`
- `consul_retry_join`, `consul_encryption_key`
- `consul_agent_token`, `consul_default_token`

#### 3. nomad-server.hcl.j2 (111 lines)
**Purpose:** Nomad server configuration template  
**Source:** Based on `shared/conf/agent-config-nomad_server.hcl`  
**Variables:**
- `datacenter`, `domain`, `inventory_hostname`
- `server_count`, `nomad_encryption_key`
- `public_ip_address`, `consul_agent_token`

#### 4. nomad-client.hcl.j2 (108 lines)
**Purpose:** Nomad client configuration template  
**Source:** Based on `shared/conf/agent-config-nomad_client.hcl`  
**Variables:**
- `datacenter`, `domain`, `inventory_hostname`
- `nomad_agent_meta`, `nomad_agent_token`

#### 5. consul-server-tokens-bootstrap.hcl.j2 (9 lines)
**Purpose:** Bootstrap token configuration  
**Source:** Based on `shared/conf/agent-config-consul_server_tokens_bootstrap.hcl`  
**Variables:**
- `consul_management_token`

#### 6. systemd-resolved-consul.conf.j2 (4 lines)
**Purpose:** DNS forwarding to Consul  
**Source:** Based on `shared/conf/systemd-service-config-resolved.conf`  
**Variables:**
- `domain`

### Policy Files

#### 1. policy-nomad-tasks.hcl (15 lines)
**Purpose:** Consul ACL policy for Nomad tasks  
**Source:** Extracted from `user-data-server.sh` lines 322-334  
**Grants:** Read keys/nodes, write services

#### 2. jwt-auth-method-config.json (11 lines)
**Purpose:** JWT auth method configuration  
**Source:** Extracted from `user-data-server.sh` lines 272-284  
**Configures:** Nomad workload identity authentication

#### 3. api-gateway-certificate.hcl (10 lines)
**Purpose:** Inline certificate for API Gateway  
**Source:** Extracted from `04.api-gateway.config.sh` lines 193-204  
**Note:** Template requiring cert/key variables

#### 4. api-gateway-config.hcl (19 lines)
**Purpose:** API Gateway listener configuration  
**Source:** Extracted from `04.api-gateway.config.sh` lines 214-234  
**Configures:** HTTPS listener on port 8443

#### 5. api-gateway-http-route.hcl (29 lines)
**Purpose:** HTTP route from gateway to nginx  
**Source:** Extracted from `04.api-gateway.config.sh` lines 244-274  
**Routes:** `/` → `nginx` service

#### 6. intentions-database.hcl (8 lines)
**Purpose:** Database service intention  
**Source:** Extracted from `04.intentions.consul.sh` lines 57-66  
**Allows:** `product-api` → `database`

#### 7. intentions-all.hcl (71 lines)
**Purpose:** Complete set of service intentions  
**Source:** Extracted from `04.intentions.consul.sh`  
**Defines:** All HashiCups service-to-service permissions

#### 8. nomad-autoscaler-policy.hcl (22 lines)
**Purpose:** Nomad ACL policy for autoscaler  
**Source:** Extracted from `05.autoscaler.config.sh` lines 54-73  
**Grants:** Scale permissions in default namespace

### Documentation

#### 1. README.md (Original)
**Purpose:** Setup and installation guide  
**Content:** HashiStack installation instructions

#### 2. CONFIGURATION_README.md (502 lines)
**Purpose:** Comprehensive configuration guide  
**Sections:**
- Directory structure
- Quick start guide
- Playbook details
- Configuration templates
- Security configuration
- Workload identity integration
- DNS configuration
- Verification steps
- Troubleshooting
- Terraform integration
- Ansible Vault usage

#### 3. policies/README.md (310 lines)
**Purpose:** Policy files documentation  
**Sections:**
- File overview
- Usage with Ansible
- Application order
- Verification commands
- Cleanup procedures
- References

## 🔄 Conversion Summary

### From Bash to Ansible

| Original File | Converted To | Lines | Type |
|--------------|--------------|-------|------|
| `setup.sh` | `setup-hashistack.yml` | 267 | Playbook |
| `user-data-server.sh` | `configure-servers.yml` | 434 | Playbook |
| `user-data-client.sh` | `configure-clients.yml` | 283 | Playbook |
| `agent-config-consul_server.hcl` | `consul-server.hcl.j2` | 131 | Template |
| `agent-config-consul_client.hcl` | `consul-client.hcl.j2` | 109 | Template |
| `agent-config-nomad_server.hcl` | `nomad-server.hcl.j2` | 111 | Template |
| `agent-config-nomad_client.hcl` | `nomad-client.hcl.j2` | 108 | Template |
| `agent-config-consul_server_tokens_bootstrap.hcl` | `consul-server-tokens-bootstrap.hcl.j2` | 9 | Template |
| `systemd-service-config-resolved.conf` | `systemd-resolved-consul.conf.j2` | 4 | Template |

### Policies Extracted

| Original Script | Policy File | Lines |
|----------------|-------------|-------|
| `user-data-server.sh` | `policy-nomad-tasks.hcl` | 15 |
| `user-data-server.sh` | `jwt-auth-method-config.json` | 11 |
| `04.api-gateway.config.sh` | `api-gateway-certificate.hcl` | 10 |
| `04.api-gateway.config.sh` | `api-gateway-config.hcl` | 19 |
| `04.api-gateway.config.sh` | `api-gateway-http-route.hcl` | 29 |
| `04.intentions.consul.sh` | `intentions-database.hcl` | 8 |
| `04.intentions.consul.sh` | `intentions-all.hcl` | 71 |
| `05.autoscaler.config.sh` | `nomad-autoscaler-policy.hcl` | 22 |

## ✨ Key Improvements

### Over Original Bash Scripts

1. **Idempotency** - Safe to run multiple times
2. **Parallel Execution** - Configures all hosts simultaneously
3. **Error Handling** - Better error reporting and recovery
4. **Modularity** - Easy to customize and extend
5. **Templating** - Dynamic configuration with Jinja2
6. **Secrets Management** - Integration with Ansible Vault
7. **Testing** - Can use `--check` mode for dry runs
8. **Logging** - Comprehensive execution logs
9. **Reusability** - Templates and tasks can be shared

### Policy Extraction Benefits

1. **Version Control** - Policies tracked separately
2. **Reusability** - Can be applied independently
3. **Documentation** - Clear purpose and usage
4. **Testing** - Can validate HCL syntax
5. **Maintenance** - Easier to update and modify

## 🎯 Usage Workflow

### Complete Deployment

```bash
# 1. Setup inventory
cp inventory.ini.example inventory.ini
# Edit inventory.ini with your hosts

# 2. Export secrets
export CONSUL_ENCRYPTION_KEY="..."
export NOMAD_ENCRYPTION_KEY="..."
export CONSUL_MANAGEMENT_TOKEN="..."
export NOMAD_MANAGEMENT_TOKEN="..."
export CA_CERTIFICATE="..."
export AGENT_CERTIFICATE="..."
export AGENT_KEY="..."

# 3. Install HashiStack
ansible-playbook setup-hashistack.yml

# 4. Configure servers
ansible-playbook configure-servers.yml

# 5. Configure clients
ansible-playbook configure-clients.yml

# 6. Verify deployment
ansible all -m shell -a "consul version"
ansible all -m shell -a "nomad version"
```

### Apply Policies

```bash
# Apply Consul policies
consul acl policy create -name policy-nomad-tasks -rules @policies/policy-nomad-tasks.hcl

# Apply API Gateway config
consul config write policies/api-gateway-config.hcl

# Apply service intentions
consul config write policies/intentions-all.hcl

# Apply Nomad autoscaler policy
nomad acl policy apply autoscaler policies/nomad-autoscaler-policy.hcl
```

## 📚 References

- [Ansible Documentation](https://docs.ansible.com/)
- [Consul Documentation](https://developer.hashicorp.com/consul)
- [Nomad Documentation](https://developer.hashicorp.com/nomad)
- [Jinja2 Documentation](https://jinja.palletsprojects.com/)

## 🔗 Related Files

- Original bash scripts: `shared/scripts/` and `shared/data-scripts/`
- Original config files: `shared/conf/`
- Job specifications: `shared/jobs/`
- Terraform code: `aws/`
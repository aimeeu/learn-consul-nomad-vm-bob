# HashiStack ACL Policies and Configurations

This directory contains HCL policy files and JSON configurations extracted from the bash scripts in `shared/jobs/`. These files can be used by Ansible playbooks or applied manually using the Consul and Nomad CLIs.

## 📁 Files Overview

### Consul ACL Policies

#### policy-nomad-tasks.hcl
**Purpose:** Grants Nomad tasks permissions to interact with Consul  
**Used by:** `nomad-default-tasks` role  
**Permissions:**
- Read keys and nodes
- Write services

**Apply:**
```bash
consul acl policy create \
  -name 'policy-nomad-tasks' \
  -description 'ACL policy used by Nomad tasks' \
  -rules @policy-nomad-tasks.hcl
```

### Consul Auth Method Configuration

#### jwt-auth-method-config.json
**Purpose:** Configures Consul to accept Nomad workload identities  
**Features:**
- JWKS URL: `https://127.0.0.1:4646/.well-known/jwks.json`
- Supported algorithms: RS256
- Bound audiences: consul.io
- Claim mappings for Nomad metadata

**Apply:**
```bash
consul acl auth-method create \
  -name 'nomad-workloads' \
  -type 'jwt' \
  -description 'JWT auth-method for Nomad services and workloads' \
  -config @jwt-auth-method-config.json
```

### API Gateway Configurations

#### api-gateway-certificate.hcl
**Purpose:** Inline certificate for API Gateway TLS  
**Note:** Template file - requires `api_gw_cert` and `api_gw_key` variables

**Apply:**
```bash
consul config write api-gateway-certificate.hcl
```

#### api-gateway-config.hcl
**Purpose:** Configures API Gateway listener on port 8443  
**Features:**
- HTTP listener
- TLS enabled with inline certificate
- Listener name: `api-gw-listener`

**Apply:**
```bash
consul config write api-gateway-config.hcl
```

#### api-gateway-http-route.hcl
**Purpose:** Routes HTTP traffic from API Gateway to nginx service  
**Route:** `/ → nginx`

**Apply:**
```bash
consul config write api-gateway-http-route.hcl
```

### Service Intentions

#### intentions-database.hcl
**Purpose:** Allow product-api to access database  
**Apply:**
```bash
consul config write intentions-database.hcl
```

#### intentions-all.hcl
**Purpose:** Complete set of service intentions for HashiCups  
**Intentions:**
- `product-api → database`
- `public-api → product-api`
- `public-api → payments-api`
- `nginx → public-api`
- `nginx → frontend`
- `api-gateway → nginx`

**Apply all:**
```bash
# Split file by --- separator and apply each section
consul config write intentions-all.hcl
```

### Nomad ACL Policies

#### nomad-autoscaler-policy.hcl
**Purpose:** Grants Nomad Autoscaler permissions to scale jobs  
**Permissions:**
- Scale policy in default namespace
- Read jobs in default namespace
- Read operator information
- Write to autoscaler lock variables

**Apply:**
```bash
nomad acl policy apply \
  -namespace default \
  -job autoscaler \
  autoscaler nomad-autoscaler-policy.hcl
```

## 🔄 Usage with Ansible

These policy files are designed to be used with Ansible playbooks. Example tasks:

### Apply Consul Policy

```yaml
- name: Create Consul ACL policy for Nomad tasks
  shell: |
    consul acl policy create \
      -name 'policy-nomad-tasks' \
      -description 'ACL policy used by Nomad tasks' \
      -rules @{{ playbook_dir }}/policies/policy-nomad-tasks.hcl
  environment:
    CONSUL_HTTP_TOKEN: "{{ consul_management_token }}"
    CONSUL_HTTP_ADDR: "http://127.0.0.1:8500"
```

### Apply Consul Config Entry

```yaml
- name: Apply API Gateway configuration
  shell: consul config write {{ playbook_dir }}/policies/api-gateway-config.hcl
  environment:
    CONSUL_HTTP_TOKEN: "{{ consul_management_token }}"
    CONSUL_HTTP_ADDR: "http://127.0.0.1:8500"
```

### Apply Nomad Policy

```yaml
- name: Apply Nomad autoscaler policy
  shell: |
    nomad acl policy apply \
      -namespace default \
      -job autoscaler \
      autoscaler {{ playbook_dir }}/policies/nomad-autoscaler-policy.hcl
  environment:
    NOMAD_TOKEN: "{{ nomad_management_token }}"
    NOMAD_ADDR: "https://localhost:4646"
    NOMAD_CACERT: "/etc/nomad.d/nomad-agent-ca.pem"
```

## 📝 Policy Application Order

For proper setup, apply policies in this order:

### 1. Consul-Nomad Integration (Server Setup)
```bash
# 1. Create auth method
consul acl auth-method create \
  -name 'nomad-workloads' \
  -type 'jwt' \
  -config @jwt-auth-method-config.json

# 2. Create binding rules (see configure-servers.yml)

# 3. Create policy
consul acl policy create \
  -name 'policy-nomad-tasks' \
  -rules @policy-nomad-tasks.hcl

# 4. Create role
consul acl role create \
  -name 'nomad-default-tasks' \
  -policy-name 'policy-nomad-tasks'
```

### 2. API Gateway Setup (Before Deploying HashiCups)
```bash
# 1. Create Nomad namespace
nomad namespace apply -description "namespace for Consul API Gateways" ingress

# 2. Create binding rule for API gateway (see 04.api-gateway.config.sh)

# 3. Generate TLS certificates (see script)

# 4. Apply certificate
consul config write api-gateway-certificate.hcl

# 5. Apply gateway config
consul config write api-gateway-config.hcl

# 6. Apply HTTP route
consul config write api-gateway-http-route.hcl
```

### 3. Service Intentions (After Deploying HashiCups)
```bash
# Apply all intentions
consul config write intentions-all.hcl
```

### 4. Autoscaler Setup (For Scaling)
```bash
nomad acl policy apply \
  -namespace default \
  -job autoscaler \
  autoscaler nomad-autoscaler-policy.hcl
```

## 🔍 Verification

### Verify Consul Policies
```bash
# List policies
consul acl policy list

# Read specific policy
consul acl policy read -name policy-nomad-tasks
```

### Verify Consul Config Entries
```bash
# List all config entries
consul config list -kind api-gateway
consul config list -kind inline-certificate
consul config list -kind http-route
consul config list -kind service-intentions

# Read specific config
consul config read -kind api-gateway -name api-gateway
```

### Verify Nomad Policies
```bash
# List policies
nomad acl policy list

# Read specific policy
nomad acl policy info autoscaler
```

## 🧹 Cleanup

### Remove Consul Configurations
```bash
# Remove route
consul config delete -kind http-route -name hashicups-http-route

# Remove certificate
consul config delete -kind inline-certificate -name api-gw-certificate

# Remove gateway
consul config delete -kind api-gateway -name api-gateway

# Remove intentions
consul config delete -kind service-intentions -name database
consul config delete -kind service-intentions -name product-api
consul config delete -kind service-intentions -name payments-api
consul config delete -kind service-intentions -name public-api
consul config delete -kind service-intentions -name frontend
consul config delete -kind service-intentions -name nginx
```

### Remove Nomad Configurations
```bash
# Delete namespace
nomad namespace delete ingress

# Delete policy
nomad acl policy delete autoscaler
```

## 📚 References

- [Consul ACL System](https://developer.hashicorp.com/consul/docs/security/acl)
- [Consul Service Intentions](https://developer.hashicorp.com/consul/docs/connect/config-entries/service-intentions)
- [Consul API Gateway](https://developer.hashicorp.com/consul/docs/connect/gateways/api-gateway)
- [Nomad ACL System](https://developer.hashicorp.com/nomad/docs/security/acl)
- [Nomad Workload Identity](https://developer.hashicorp.com/nomad/docs/concepts/workload-identity)
- [Nomad Autoscaler](https://developer.hashicorp.com/nomad/tools/autoscaling)

## 🔗 Related Scripts

These policies were extracted from:
- `shared/data-scripts/user-data-server.sh` - Server bootstrap policies
- `shared/jobs/04.api-gateway.config.sh` - API Gateway setup
- `shared/jobs/04.intentions.consul.sh` - Service intentions
- `shared/jobs/05.autoscaler.config.sh` - Autoscaler policies
#!/bin/bash

set -e

# Redirects output on file
exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

#-------------------------------------------------------------------------------
# Configure and start servers
#-------------------------------------------------------------------------------

# Paths for configuration files
#-------------------------------------------------------------------------------

echo "Setup configuration PATHS"

CONFIG_DIR=/ops/shared/conf

CONSUL_CONFIG_DIR=/etc/consul.d
VAULT_CONFIG_DIR=/etc/vault.d
NOMAD_CONFIG_DIR=/etc/nomad.d
CONSULTEMPLATE_CONFIG_DIR=/etc/consul-template.d

HOME_DIR=ubuntu

# Retrieve certificates
#-------------------------------------------------------------------------------

echo "Create TLS certificate files"

echo "${ca_certificate}"    | base64 -d | zcat > /tmp/agent-ca.pem
echo "${agent_certificate}" | base64 -d | zcat > /tmp/agent.pem
echo "${agent_key}"         | base64 -d | zcat > /tmp/agent-key.pem

sudo cp /tmp/agent-ca.pem $CONSUL_CONFIG_DIR/consul-agent-ca.pem
sudo cp /tmp/agent.pem $CONSUL_CONFIG_DIR/consul-agent.pem
sudo cp /tmp/agent-key.pem $CONSUL_CONFIG_DIR/consul-agent-key.pem

sudo cp /tmp/agent-ca.pem $NOMAD_CONFIG_DIR/nomad-agent-ca.pem
sudo cp /tmp/agent.pem $NOMAD_CONFIG_DIR/nomad-agent.pem
sudo cp /tmp/agent-key.pem $NOMAD_CONFIG_DIR/nomad-agent-key.pem

# IP addresses
#-------------------------------------------------------------------------------

echo "Retrieve IP addresses"

# Wait for network
## todo testi if this value is not too big
sleep 15

DOCKER_BRIDGE_IP_ADDRESS=`ip -brief addr show docker0 | awk '{print $3}' | awk -F/ '{print $1}'`

CLOUD="${cloud_env}"

# Get IP from metadata service
case $CLOUD in
  aws)
    echo "CLOUD_ENV: aws"
    TOKEN=$(curl -X PUT "http://instance-data/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

    IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/local-ipv4)
    PUBLIC_IP_ADDRESS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://instance-data/latest/meta-data/public-ipv4)
    ;;
  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;
  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;
  *)
    echo "CLOUD_ENV: not set"
    ;;
esac

# Environment variables
#-------------------------------------------------------------------------------

echo "Setup Environment variables"

# consul.hcl variables needed
CONSUL_DATACENTER="${datacenter}"
CONSUL_DOMAIN="${domain}"
CONSUL_NODE_NAME="${consul_node_name}"
CONSUL_SERVER_COUNT="${server_count}"
CONSUL_BIND_ADDR="$IP_ADDRESS"
CONSUL_RETRY_JOIN="${retry_join}"
CONSUL_ENCRYPTION_KEY="${consul_encryption_key}"
CONSUL_MANAGEMENT_TOKEN="${consul_management_token}"

# nomad.hcl variables needed
NOMAD_DATACENTER="${datacenter}"
NOMAD_DOMAIN="${domain}"
NOMAD_NODE_NAME="${nomad_node_name}"
NOMAD_SERVER_COUNT="${server_count}"
NOMAD_ENCRYPTION_KEY="${nomad_encryption_key}"
CONSUL_PUBLIC_BIND_ADDR="$PUBLIC_IP_ADDRESS"

NOMAD_MANAGEMENT_TOKEN="${nomad_management_token}"

# Configuration file destinations
_JWT_FILE="${jwt_file}"
_POLICY_NOMAD_TASKS="${nomad_tasks_policy_file}"

# Configure and start Consul
#-------------------------------------------------------------------------------

echo "Create Consul configuration files"

# Copy template into Consul configuration directory
sudo cp $CONFIG_DIR/agent-config-consul_server.hcl $CONSUL_CONFIG_DIR/consul.hcl


set -x

# Populate the file with values from the variables
sudo sed -i "s/_CONSUL_DATACENTER/$CONSUL_DATACENTER/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_DOMAIN/$CONSUL_DOMAIN/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_NODE_NAME/$CONSUL_NODE_NAME/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_SERVER_COUNT/$CONSUL_SERVER_COUNT/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_BIND_ADDR/$CONSUL_BIND_ADDR/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s/_CONSUL_RETRY_JOIN/$CONSUL_RETRY_JOIN/g" $CONSUL_CONFIG_DIR/consul.hcl
sudo sed -i "s#_CONSUL_ENCRYPTION_KEY#$CONSUL_ENCRYPTION_KEY#g" $CONSUL_CONFIG_DIR/consul.hcl

set +x 

# Copy Bootstrap token configuration into Consul configuration directory
sudo cp $CONFIG_DIR/agent-config-consul_server_tokens_bootstrap.hcl $CONSUL_CONFIG_DIR/consul_tokens.hcl
sudo sed -i "s/_CONSUL_MANAGEMENT_TOKEN/$CONSUL_MANAGEMENT_TOKEN/g" $CONSUL_CONFIG_DIR/consul_tokens.hcl

# Start Consul
echo "Start Consul"
sudo systemctl enable consul.service
sudo systemctl start consul.service

# curl http://localhost:8500/v1/status/leader

## todo instead of sleeping check on status https://developer.hashicorp.com/consul/api-docs/status
sleep 30

# curl http://localhost:8500/v1/status/leader

## todo generate AGENT and DEFAULT tokens for Consul and remove the consul_tokens.hcl config file.
echo "Generate ACL tokens for Consul servers"

OUTPUT=$(CONSUL_HTTP_TOKEN=$CONSUL_MANAGEMENT_TOKEN consul acl token create -description="Server Agent token for $CONSUL_NODE_NAME " --format json -templated-policy="builtin/node" -var name:$CONSUL_NODE_NAME)
CONSUL_SERVER_TOKEN=$(echo "$OUTPUT" | jq -r ".SecretID")
CONSUL_HTTP_TOKEN=$CONSUL_MANAGEMENT_TOKEN consul acl set-agent-token agent $CONSUL_SERVER_TOKEN

OUTPUT=$(CONSUL_HTTP_TOKEN=$CONSUL_MANAGEMENT_TOKEN consul acl token create -description="Server Default token for $CONSUL_NODE_NAME" --format json -templated-policy="builtin/dns")
CONSUL_DNS_TOKEN=$(echo "$OUTPUT" | jq -r ".SecretID")
CONSUL_HTTP_TOKEN=$CONSUL_MANAGEMENT_TOKEN consul acl set-agent-token default $CONSUL_DNS_TOKEN


# Configure and start Nomad
#-------------------------------------------------------------------------------

echo "Create Nomad configuration files"

# Create Nomad server token to interact with Consul
OUTPUT=$(CONSUL_HTTP_TOKEN=$CONSUL_MANAGEMENT_TOKEN consul acl token create -description="Nomad server auto-join token for $CONSUL_NODE_NAME" --format json -templated-policy="builtin/nomad-server")
CONSUL_AGENT_TOKEN=$(echo "$OUTPUT" | jq -r ".SecretID")

# Copy template into Nomad configuration directory
sudo cp $CONFIG_DIR/agent-config-nomad_server.hcl $NOMAD_CONFIG_DIR/nomad.hcl

# Populate the file with values from the variables
sudo sed -i "s/_NOMAD_DATACENTER/$NOMAD_DATACENTER/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_DOMAIN/$NOMAD_DOMAIN/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_NODE_NAME/$NOMAD_NODE_NAME/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_NOMAD_SERVER_COUNT/$NOMAD_SERVER_COUNT/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s#_NOMAD_ENCRYPTION_KEY#$NOMAD_ENCRYPTION_KEY#g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_CONSUL_IP_ADDRESS/$CONSUL_PUBLIC_BIND_ADDR/g" $NOMAD_CONFIG_DIR/nomad.hcl
sudo sed -i "s/_CONSUL_AGENT_TOKEN/$CONSUL_AGENT_TOKEN/g" $NOMAD_CONFIG_DIR/nomad.hcl

echo "Start Nomad"

sudo systemctl enable nomad.service
sudo systemctl start nomad.service

## todo instead of sleeping check on status https://developer.hashicorp.com/nomad/api-docs/status
sleep 10

# Configure consul-template
#-------------------------------------------------------------------------------
echo "Create consul-template configuration files"
sudo cp $CONFIG_DIR/agent-config-consul_template.hcl $CONSULTEMPLATE_CONFIG_DIR/consul-template.hcl
sudo cp $CONFIG_DIR/systemd-service-consul_template.service /etc/systemd/system/consul-template.service

# Configure DNS
#-------------------------------------------------------------------------------

echo "Configure DNS"

# Add hostname to /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add systemd-resolved configuration for Consul DNS
# ref: https://developer.hashicorp.com/consul/tutorials/networking/dns-forwarding#systemd-resolved-setup
sudo mkdir -p /etc/systemd/resolved.conf.d/
sudo cp $CONFIG_DIR/systemd-service-config-resolved.conf /etc/systemd/resolved.conf.d/consul.conf

sudo sed -i "s/_CONSUL_DOMAIN/$CONSUL_DOMAIN/g" /etc/systemd/resolved.conf.d/consul.conf
sudo sed -i "s/_DOCKER_BRIDGE_IP_ADDRESS/$DOCKER_BRIDGE_IP_ADDRESS/g" /etc/systemd/resolved.conf.d/consul.conf

sudo systemctl restart systemd-resolved

#-------------------------------------------------------------------------------
# Boostrap Servers
#-------------------------------------------------------------------------------

# Bootstrap Consul
#-------------------------------------------------------------------------------

# Consul is already bootstrapped using the initial management token 

# Bootstrap Nomad
#-------------------------------------------------------------------------------

echo "Bootstrap Nomad"

# Wait for nomad servers to come up and bootstrap nomad ACL
for i in {1..12}; do
    # capture stdout and stderr
    set +e
    sleep 5
    set -x 
    export NOMAD_ADDR="https://localhost:4646"
    export NOMAD_CACERT="$NOMAD_CONFIG_DIR/nomad-agent-ca.pem"

    OUTPUT=$(echo "$NOMAD_MANAGEMENT_TOKEN" | nomad acl bootstrap - 2>&1)
    if [ $? -ne 0 ]; then
        echo "nomad acl bootstrap: $OUTPUT"
        if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
            echo "nomad no cluster leader"
            continue
        else
            echo "nomad already bootstrapped"
            exit 0
        fi
    else 
        echo "nomad bootstrapped"
        break
    fi
    set +x 
    set -e
done

## todo instead of sleeping check on status https://developer.hashicorp.com/nomad/api-docs/status
sleep 30

#------------------------
# Create Consul-Nomad ACL workload identity integration because
#  nomad.hcl consul config block contains service_identity and task_identity
# https://developer.hashicorp.com/nomad/docs/secure/acl/consul#configuring-consul-authentication
# Moved from 04.api-gateway.config.sh
# ------------------------
# @TODO the problem here is that this script runs before Terraform outputs.tf.
# The 04.api-gateway.config.sh script sources the datacenter.env file to get the env variables.
# Also not sure why JWKSCACert is used since that's not in the docs, so removed



## -----------------------------------------------------------------------------
## Configure Consul and Nomad ACL integration
## -----------------------------------------------------------------------------

echo -e "Create Consul auth-method 'nomad-workloads'"

tee ${_JWT_FILE} > /dev/null << EOF
{
  "JWKSURL": "https://127.0.0.1:4646/.well-known/jwks.json",
  "JWTSupportedAlgs": ["RS256"],
  "BoundAudiences": ["consul.io"],
  "ClaimMappings": {
    "nomad_namespace": "nomad_namespace",
    "nomad_job_id": "nomad_job_id",
    "nomad_task": "nomad_task",
    "nomad_service": "nomad_service"
  }
}
EOF

# This auth method creates an endpoint for generating Consul ACL tokens 
#  from Nomad workload identities.
consul acl auth-method create \
            -name 'nomad-workloads' \
            -type 'jwt' \
            -description 'JWT auth-method for Nomad services and workloads' \
            -config "@${_JWT_FILE}"

# -----------------------------------------------------------------------------
# Create workload identity artifacts for HashiCups, which runs in the default namespace
# https://developer.hashicorp.com/nomad/tutorials/integrate-consul/consul-acl#configure-consul-for-tasks-workload-identities
# https://developer.hashicorp.com/nomad/commands/setup/consul
# -----------------------------------------------------------------------------

echo -e "Create Consul binding-rule for Nomad services not in ingress namespace"

# Binding rule for Nomad services running in the 'default' namespace
consul acl binding-rule create \
           -method 'nomad-workloads' \
           -description 'Binding rule for Nomad services authenticated using a workload identity' \
           -bind-type 'service' \
           -bind-name '${value.nomad_service}' \
           -selector '"nomad_service" in value'

echo -e "Create Consul binding-rule for Nomad tasks not in ingress namespace."

# Bind rule for Nomad tasks running in the 'default' namespace
consul acl binding-rule create \
           -method 'nomad-workloads' \
           -description 'Binding rule for Nomad tasks authenticated using a workload identity' \
           -bind-type 'role' \
           -bind-name 'nomad-${value.nomad_namespace}-tasks' \
           -selector '"nomad_service" not in value'

echo -e "$Create Consul ACL policy 'policy-nomad-tasks' for Nomad tasks."

tee ${_POLICY_NOMAD_TASKS} > /dev/null << EOF
key_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "write"
}
EOF

consul acl policy create \
            -name 'policy-nomad-tasks' \
            -description 'ACL policy used by Nomad tasks' \
            -rules @${_POLICY_NOMAD_TASKS}

echo -e "Create Consul ACL role 'nomad-default-tasks' for Nomad tasks."

consul acl role create \
           -name 'nomad-default-tasks' \
           -description 'ACL role for Nomad tasks in the default Nomad namespace' \
           -policy-name 'policy-nomad-tasks'


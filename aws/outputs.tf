# Exports all needed environment variables to connect to Consul and Nomad 
# datacenter using CLI commands
resource "local_file" "environment_variables" {
  filename = "datacenter.env"
  content  = <<-EOT
    export CONSUL_HTTP_ADDR="https://${aws_instance.server[0].public_ip}:8443"
    export CONSUL_HTTP_TOKEN="${random_uuid.consul_mgmt_token.result}"
    export CONSUL_HTTP_SSL="true"
    export CONSUL_CACERT="${path.cwd}/certs/datacenter_ca.cert"
    export CONSUL_TLS_SERVER_NAME="consul.${var.datacenter}.${var.domain}"
    export NOMAD_ADDR="https://${aws_instance.server[0].public_ip}:4646"
    export NOMAD_TOKEN="${random_uuid.nomad_mgmt_token.result}"
    export NOMAD_CACERT="${path.cwd}/certs/datacenter_ca.cert"
    export NOMAD_TLS_SERVER_NAME="nomad.${var.datacenter}.${var.domain}"
  EOT
}

output "Configure-local-environment" {
  value = "source ./datacenter.env"
}

output "Consul_UI" {
  value = "https://${aws_instance.server[0].public_ip}:8443"
}

output "Nomad_UI" {
  value = "https://${aws_instance.server[0].public_ip}:4646"
}

output "Nomad_UI_token" {
  value     = random_uuid.nomad_mgmt_token.result
  sensitive = true
}

output "Consul_UI_token" {
  value     = random_uuid.consul_mgmt_token.result
  sensitive = true
}

#-------------------------------------------------------------------------------
# Per-host TLS cert and key files for Ansible
#-------------------------------------------------------------------------------

resource "local_file" "server_cert_file" {
  count           = var.server_count
  content         = tls_locally_signed_cert.server_cert[count.index].cert_pem
  filename        = "${path.module}/certs/consul-server-${count.index}.cert"
  file_permission = "0644"
}

resource "local_file" "server_key_file" {
  count           = var.server_count
  content         = tls_private_key.server_key[count.index].private_key_pem
  filename        = "${path.module}/certs/consul-server-${count.index}.key"
  file_permission = "0400"
}

resource "local_file" "client_cert_file" {
  count           = var.client_count
  content         = tls_locally_signed_cert.client_cert[count.index].cert_pem
  filename        = "${path.module}/certs/consul-client-${count.index}.cert"
  file_permission = "0644"
}

resource "local_file" "client_key_file" {
  count           = var.client_count
  content         = tls_private_key.client_key[count.index].private_key_pem
  filename        = "${path.module}/certs/consul-client-${count.index}.key"
  file_permission = "0400"
}

resource "local_file" "public_client_cert_file" {
  count           = var.public_client_count
  content         = tls_locally_signed_cert.public_client_cert[count.index].cert_pem
  filename        = "${path.module}/certs/consul-public-client-${count.index}.cert"
  file_permission = "0644"
}

resource "local_file" "public_client_key_file" {
  count           = var.public_client_count
  content         = tls_private_key.public_client_key[count.index].private_key_pem
  filename        = "${path.module}/certs/consul-public-client-${count.index}.key"
  file_permission = "0400"
}

#-------------------------------------------------------------------------------
# Ansible inventory files
#
# inventory-servers.yml  - phase 1: no consul provider dependencies; used to
#                          configure server nodes before the consul provider
#                          can connect.
# inventory.yml          - phase 2: full inventory including client ACL tokens;
#                          generated after Consul is running and consul provider
#                          resources have been applied.
#-------------------------------------------------------------------------------

resource "local_file" "ansible_inventory_servers" {
  filename        = "${path.module}/inventory-servers.yml"
  file_permission = "0600"
  content = templatefile("${path.module}/../shared/ansible/inventory-servers.yml.tftpl", {
    ssh_key_file            = "${path.module}/certs/aws-key-pair.pem"
    certs_dir               = "${path.module}/certs"
    datacenter              = var.datacenter
    domain                  = var.domain
    server_count            = tostring(var.server_count)
    retry_join              = local.retry_join_consul
    consul_encryption_key   = random_id.consul_gossip_key.b64_std
    nomad_encryption_key    = random_id.nomad_gossip_key.b64_std
    consul_management_token = random_uuid.consul_mgmt_token.result
    nomad_management_token  = random_uuid.nomad_mgmt_token.result
    servers = [for i in range(var.server_count) : {
      name             = "consul-server-${i}"
      public_ip        = aws_instance.server[i].public_ip
      private_ip       = aws_instance.server[i].private_ip
      consul_node_name = "consul-server-${i}"
      nomad_node_name  = "nomad-server-${i}"
    }]
  })
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/inventory.yml"
  file_permission = "0600"
  content = templatefile("${path.module}/../shared/ansible/inventory.yml.tftpl", {
    ssh_key_file            = "${path.module}/certs/aws-key-pair.pem"
    certs_dir               = "${path.module}/certs"
    datacenter              = var.datacenter
    domain                  = var.domain
    server_count            = tostring(var.server_count)
    retry_join              = local.retry_join_consul
    consul_encryption_key   = random_id.consul_gossip_key.b64_std
    nomad_encryption_key    = random_id.nomad_gossip_key.b64_std
    consul_management_token = random_uuid.consul_mgmt_token.result
    nomad_management_token  = random_uuid.nomad_mgmt_token.result
    servers = [for i in range(var.server_count) : {
      name             = "consul-server-${i}"
      public_ip        = aws_instance.server[i].public_ip
      private_ip       = aws_instance.server[i].private_ip
      consul_node_name = "consul-server-${i}"
      nomad_node_name  = "nomad-server-${i}"
    }]
    clients = [for i in range(var.client_count) : {
      name                 = "consul-client-${i}"
      public_ip            = aws_instance.client[i].public_ip
      private_ip           = aws_instance.client[i].private_ip
      consul_node_name     = "consul-client-${i}"
      nomad_node_name      = "nomad-client-${i}"
      nomad_agent_meta     = "isPublic = false"
      consul_agent_token   = data.consul_acl_token_secret_id.consul-client-agent-token[i].secret_id
      consul_default_token = data.consul_acl_token_secret_id.consul-client-default-token[i].secret_id
      nomad_agent_token    = data.consul_acl_token_secret_id.nomad-client-consul-token[i].secret_id
    }]
    public_clients = [for i in range(var.public_client_count) : {
      name                 = "consul-public-client-${i}"
      public_ip            = aws_instance.public_client[i].public_ip
      private_ip           = aws_instance.public_client[i].private_ip
      consul_node_name     = "consul-public-client-${i}"
      nomad_node_name      = "nomad-public-client-${i}"
      nomad_agent_meta     = "isPublic = true, nodeRole = \"ingress\""
      consul_agent_token   = data.consul_acl_token_secret_id.consul-public-client-agent-token[i].secret_id
      consul_default_token = data.consul_acl_token_secret_id.consul-public-client-default-token[i].secret_id
      nomad_agent_token    = data.consul_acl_token_secret_id.nomad-public-client-consul-token[i].secret_id
    }]
  })
}
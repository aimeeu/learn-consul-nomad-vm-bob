# Consul ACL Policy for Nomad Tasks
# This policy grants Nomad tasks the necessary permissions to interact with Consul
# Used by: nomad-default-tasks role

key_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "write"
}
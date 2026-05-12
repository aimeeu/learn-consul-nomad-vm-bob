# Nomad ACL Policy for Autoscaler
# Grants the autoscaler permissions to scale jobs in the default namespace

namespace "default" {
  policy = "scale"
}

namespace "default" {
  capabilities = ["read-job"]
}

operator {
  policy = "read"
}

namespace "default" {
  variables {
    path "nomad-autoscaler/lock" {
      capabilities = ["write"]
    }
  }
}
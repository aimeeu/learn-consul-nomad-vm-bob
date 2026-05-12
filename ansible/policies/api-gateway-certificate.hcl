Kind = "inline-certificate"
Name = "api-gw-certificate"

Certificate = <<EOT
{{ api_gw_cert }}
EOT

PrivateKey = <<EOT
{{ api_gw_key }}
EOT
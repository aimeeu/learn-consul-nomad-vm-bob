Kind = "api-gateway"
Name = "api-gateway"

// Each listener configures a port which can be used to access the Consul cluster
Listeners = [
    {
        Port = 8443
        Name = "api-gw-listener"
        Protocol = "http"
        TLS = {
            Certificates = [
                {
                    Kind = "inline-certificate"
                    Name = "api-gw-certificate"
                }
            ]
        }
    }
]
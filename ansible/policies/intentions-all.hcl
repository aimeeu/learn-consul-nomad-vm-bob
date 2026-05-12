# Consul Service Intentions for HashiCups Application
# This file contains all service-to-service communication intentions

# Database - Allow product-api to access database
Kind = "service-intentions"
Name = "database"
Sources = [
  {
    Name   = "product-api"
    Action = "allow"
  }
]

---

# Product API - Allow public-api to access product-api
Kind = "service-intentions"
Name = "product-api"
Sources = [
  {
    Name   = "public-api"
    Action = "allow"
  }
]

---

# Payments API - Allow public-api to access payments-api
Kind = "service-intentions"
Name = "payments-api"
Sources = [
  {
    Name   = "public-api"
    Action = "allow"
  }
]

---

# Public API - Allow nginx to access public-api
Kind = "service-intentions"
Name = "public-api"
Sources = [
  {
    Name   = "nginx"
    Action = "allow"
  }
]

---

# Frontend - Allow nginx to access frontend
Kind = "service-intentions"
Name = "frontend"
Sources = [
  {
    Name   = "nginx"
    Action = "allow"
  }
]

---

# NGINX - Allow api-gateway to access nginx
Kind = "service-intentions"
Name = "nginx"
Sources = [
  {
    Name   = "api-gateway"
    Action = "allow"
  }
]
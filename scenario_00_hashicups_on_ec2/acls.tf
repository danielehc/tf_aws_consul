// Wait for Consul to be up
// TODO make it parametric or able to understand server count
# resource "time_sleep" "wait_30_seconds" {
#   depends_on = [aws_instance.consul_server[0]]

#   create_duration = "30s"
# }

resource "consul_acl_policy" "test-policy" {
  depends_on = [aws_instance.consul_server]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "test"
  datacenters = [ var.consul_datacenter]
  rules       = templatefile("${path.module}/conf/consul/acl-policy-svc.hcl.tmpl", { 
    SERVICE    = "test"
  })
}


resource "consul_acl_policy" "hashicups-db-policy" {
  # count       = "${var.auto_acl_bootstrap} * ${var.auto_acl_bootstrap}"
  depends_on = [aws_instance.consul_server]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-db"
  datacenters = [ var.consul_datacenter]
  rules       = <<-RULE
    # Allow the service and its sidecar proxy to register into the catalog.
    service "hashicups-db" {
        policy = "write"
    }

    service "hashicups-db-sidecar-proxy" {
        policy = "write"
    }
    
    node_prefix "" {
        policy = "read"
    }

    # Allow the agent to register its own node in the Catalog and update its network coordinates
    node "hashicups-db" {
      policy = "write"
    }

    # Allows the agent to detect and diff services registered to itself. This is used during
    # anti-entropy to reconcile difference between the agents knowledge of registered
    # services and checks in comparison with what is known in the Catalog.
    service_prefix "" {
      policy = "read"
    }
    RULE

}

resource "consul_acl_policy" "hashicups-api-policy" {
  depends_on = [aws_instance.consul_server]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-api"
  datacenters = [ var.consul_datacenter]
  rules       = <<-RULE
    # Allow the service and its sidecar proxy to register into the catalog.
    service "hashicups-api" {
        policy = "write"
    }

    service "hashicups-api-sidecar-proxy" {
        policy = "write"
    }
    
    node_prefix "" {
        policy = "read"
    }

    # Allow the agent to register its own node in the Catalog and update its network coordinates
    node "hashicups-api" {
      policy = "write"
    }

    # Allows the agent to detect and diff services registered to itself. This is used during
    # anti-entropy to reconcile difference between the agents knowledge of registered
    # services and checks in comparison with what is known in the Catalog.
    service_prefix "" {
      policy = "read"
    }
    RULE

}

resource "consul_acl_policy" "hashicups-frontend-policy" {
  depends_on = [aws_instance.consul_server]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-frontend"
  datacenters = [ var.consul_datacenter]
  rules       = <<-RULE
    # Allow the service and its sidecar proxy to register into the catalog.
    service "hashicups-frontend" {
        policy = "write"
    }

    service "hashicups-frontend-sidecar-proxy" {
        policy = "write"
    }
    
    node_prefix "" {
        policy = "read"
    }

    # Allow the agent to register its own node in the Catalog and update its network coordinates
    node "hashicups-frontend" {
      policy = "write"
    }

    # Allows the agent to detect and diff services registered to itself. This is used during
    # anti-entropy to reconcile difference between the agents knowledge of registered
    # services and checks in comparison with what is known in the Catalog.
    service_prefix "" {
      policy = "read"
    }
    RULE

}

resource "consul_acl_policy" "hashicups-nginx-policy" {
  depends_on = [aws_instance.consul_server]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-nginx"
  datacenters = [ var.consul_datacenter]
  rules       = <<-RULE
    # Allow the service and its sidecar proxy to register into the catalog.
    service "hashicups-nginx" {
        policy = "write"
    }

    service "hashicups-nginx-sidecar-proxy" {
        policy = "write"
    }
    
    node_prefix "" {
        policy = "read"
    }

    # Allow the agent to register its own node in the Catalog and update its network coordinates
    node "hashicups-nginx" {
      policy = "write"
    }

    # Allows the agent to detect and diff services registered to itself. This is used during
    # anti-entropy to reconcile difference between the agents knowledge of registered
    # services and checks in comparison with what is known in the Catalog.
    service_prefix "" {
      policy = "read"
    }
    RULE

}

resource "consul_acl_token" "hashicups-db-token" {
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-db-token"
  policies    = ["${consul_acl_policy.hashicups-db-policy[0].name}"]
  local       = true

}

resource "consul_acl_token" "hashicups-api-token" {
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-api-token"
  policies    = ["${consul_acl_policy.hashicups-api-policy[0].name}"]
  local       = true

}

resource "consul_acl_token" "hashicups-frontend-token" {
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-frontend-token"
  policies    = ["${consul_acl_policy.hashicups-frontend-policy[0].name}"]
  local       = true

}

resource "consul_acl_token" "hashicups-nginx-token" {
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-nginx-token"
  policies    = ["${consul_acl_policy.hashicups-nginx-policy[0].name}"]
  local       = true

}
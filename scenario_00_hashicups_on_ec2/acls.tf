// Wait for Consul to be up
// TODO make it parametric or able to understand server count
# resource "time_sleep" "wait_30_seconds" {
#   depends_on = [aws_instance.consul_server[0]]

#   create_duration = "30s"
# }


resource "consul_acl_policy" "hashicups-db-policy" {
  # count       = "${var.auto_acl_bootstrap} * ${var.auto_acl_bootstrap}"
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-db"
  datacenters = [ var.consul_datacenter]
  rules       = templatefile("${path.module}/conf/consul/acl-policy-svc.hcl.tmpl", { 
    SERVICE    = "hashicups-db"
  })
}

resource "consul_acl_policy" "hashicups-api-policy" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-api"
  datacenters = [ var.consul_datacenter]
  rules       = templatefile("${path.module}/conf/consul/acl-policy-svc.hcl.tmpl", { 
    SERVICE    = "hashicups-api"
  })
}

resource "consul_acl_policy" "hashicups-frontend-policy" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-frontend"
  datacenters = [ var.consul_datacenter]
  rules       = templatefile("${path.module}/conf/consul/acl-policy-svc.hcl.tmpl", { 
    SERVICE    = "hashicups-frontend"
  })
}

resource "consul_acl_policy" "hashicups-nginx-policy" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  name        = "hashicups-nginx"
  datacenters = [ var.consul_datacenter]
  rules       = templatefile("${path.module}/conf/consul/acl-policy-svc.hcl.tmpl", { 
    SERVICE    = "hashicups-nginx"
  })
}

resource "consul_acl_token" "hashicups-db-token" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-db-token"
  policies    = ["${consul_acl_policy.hashicups-db-policy[0].name}"]
  local       = true

}

resource "consul_acl_token" "hashicups-api-token" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-api-token"
  policies    = ["${consul_acl_policy.hashicups-api-policy[0].name}"]
  local       = true

}

resource "consul_acl_token" "hashicups-frontend-token" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-frontend-token"
  policies    = ["${consul_acl_policy.hashicups-frontend-policy[0].name}"]
  local       = true

}

resource "consul_acl_token" "hashicups-nginx-token" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  description = "hashicups-nginx-token"
  policies    = ["${consul_acl_policy.hashicups-nginx-policy[0].name}"]
  local       = true

}

data "consul_acl_token_secret_id" "hashicups-db-token-secret" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  accessor_id = consul_acl_token.hashicups-db-token[0].id
}

data "consul_acl_token_secret_id" "hashicups-api-token-secret" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  accessor_id = consul_acl_token.hashicups-api-token[0].id
}

data "consul_acl_token_secret_id" "hashicups-frontend-token-secret" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  accessor_id = consul_acl_token.hashicups-frontend-token[0].id
}

data "consul_acl_token_secret_id" "hashicups-nginx-token-secret" {
  depends_on = [aws_instance.consul_server, module.vpc]
  count       = var.auto_acl_bootstrap ? var.auto_acl_clients ? 1 : 0 : 0
  accessor_id = consul_acl_token.hashicups-nginx-token[0].id
}
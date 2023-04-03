// A variable for extracting the external ip of the instance
output "ip_bastion" {
  value = aws_instance.bastion.public_ip
}

output "connection_string" {
  value = "ssh -i certs/id_rsa.pem admin@${aws_instance.bastion.public_ip}"
}


output "ip_db" {
  value = aws_instance.database.public_ip
}

output "ip_api" {
  value = aws_instance.api.public_ip
}

output "ip_fe" {
  value = aws_instance.frontend.public_ip
}

output "ip_nginx" {
  value = aws_instance.nginx.public_ip
}

output "ip_consul" {
  value = aws_instance.consul_server[*].public_ip
}

output "ui_hashicups" {
  value = "http://${aws_instance.nginx.public_ip}"
}

output "ui_consul" {
  value = "https://${aws_instance.consul_server.0.public_ip}:8443"
}

output "ui_grafana" {
  value = "http://${aws_instance.bastion.public_ip}:3000"
}

output "ui_loki" {
  value = "http://${aws_instance.bastion.public_ip}:3100"
}

output "ui_mimir" {
  value = "http://${aws_instance.bastion.public_ip}:9009"
}

# output "hosts" {
#   value = local.bastion_fake_dns
# }

# output "consul_acl_token" {
#   value = var.auto_acl_bootstrap ? "${random_uuid.bootstrap-token.id}" : "ACL not bootstrapped"
# }

# output "consul_ui_url" {
#   value = "https://${aws_instance.consul_server.0.public_ip}:8443"
# }

# locals {
#   token = var.auto_acl_bootstrap ? "${random_uuid.bootstrap-token.id}" : ""
# }

# output "consul_cli_config" {
#   value = <<CONSULCONFIG

#       export CONSUL_HTTP_ADDR="https://${aws_instance.consul_server.0.public_ip}:8443"
#       export CONSUL_HTTP_TOKEN="${local.token}"
#       export CONSUL_HTTP_SSL=true
#       export CONSUL_CACERT="certs/consul-agent-ca.pem"
#       export CONSUL_TLS_SERVER_NAME="server.${var.consul_datacenter}.${var.consul_domain}"
#   CONSULCONFIG
# }

# output "gossip" {
#   value = "${random_id.gossip_key.id} - ${random_id.gossip_key.b64_std}"
# }
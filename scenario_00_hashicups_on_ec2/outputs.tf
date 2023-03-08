// A variable for extracting the external ip of the instance
output "bastion_ip" {
  value = aws_instance.bastion.public_ip
}

output "hashicups_ui" {
  value = "http://${aws_instance.nginx.public_ip}"
}

output connection_string {
  value = "ssh -i id_rsa.pem admin@${aws_instance.bastion.public_ip}"
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
  value = aws_instance.consul_server.0.public_ip
}

# output "gossip" {
#   value = "${random_id.gossip_key.id} - ${random_id.gossip_key.b64_std}"
# }
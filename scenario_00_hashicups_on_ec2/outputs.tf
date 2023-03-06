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
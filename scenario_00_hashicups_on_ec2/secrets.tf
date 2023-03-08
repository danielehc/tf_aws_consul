#------------------------------------------------------------------------------#
# Key/Cert for SSH connection to the hosts
#------------------------------------------------------------------------------#
resource "tls_private_key" "keypair_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = "id_rsa.pub"
  public_key = tls_private_key.keypair_private_key.public_key_openssh

  # Create "id_rsa.pem" in local directory
  provisioner "local-exec" { 
    command = "rm -rf id_rsa.pem && echo '${tls_private_key.keypair_private_key.private_key_pem}' > id_rsa.pem && chmod 400 id_rsa.pem"
  }
}


#------------------------------------------------------------------------------#
## Gossip Encryption Key
#------------------------------------------------------------------------------#
resource "random_id" "gossip_key" {
  byte_length = 32
}


#------------------------------------------------------------------------------#
## CA for Consul datacenter
#------------------------------------------------------------------------------#
resource "tls_private_key" "ca" {
  algorithm   = "RSA" #"${var.private_key_algorithm}"
  rsa_bits    = "4096" #"${var.private_key_rsa_bits}"
#   ecdsa_curve = "${var.private_key_ecdsa_curve}"
}

# CA Certificate
resource "tls_self_signed_cert" "ca" {
#   key_algorithm         = "${tls_private_key.ca.algorithm}"
  private_key_pem       = "${tls_private_key.ca.private_key_pem}"
  is_ca_certificate     = true
  validity_period_hours = 8760 #"${var.validity_period_hours}"
  allowed_uses          = ["digital_signature","crl_signing", "cert_signing"] #["${var.ca_allowed_uses}"]

  subject {
    common_name  = "${var.consul_datacenter}.${var.consul_domain}"
    organization = "HashiCorp Learn Consul"# "${var.organization_name}"
  }
}

resource "local_file" "ca_public_key" {
  content  = "${tls_self_signed_cert.ca.cert_pem}"
  filename = "consul-agent-ca.pem"#"${var.ca_public_key_path}"
}

#------------------------------------------------------------------------------#
# Consul Server Certificate
#------------------------------------------------------------------------------#
resource "tls_private_key" "server_cert" {
  algorithm   = "RSA" 
  rsa_bits    = "4096"
}

# resource "local_file" "cert_file" {
#   content  = "${tls_private_key.server_cert.private_key_pem}"
#   filename = "${var.cert_private_key_path}"
# }

resource "tls_cert_request" "server_cert" {
#   key_algorithm   = "${tls_private_key.server_cert.algorithm}"
  private_key_pem = "${tls_private_key.server_cert.private_key_pem}"

  dns_names = ["server.${var.consul_datacenter}.${var.consul_domain}", "localhost"]
  ip_addresses = ["127.0.0.1"]

  subject {
    common_name  = "${var.consul_datacenter}.${var.consul_domain}"
    organization = "HashiCorp Learn Consul"
  }
}

resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem = "${tls_cert_request.server_cert.cert_request_pem}"

#   ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 8760
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth", "client_auth"]
}

# resource "local_file" "cert_public_key" {
#   content  = "${tls_locally_signed_cert.cert.cert_pem}"
#   filename = "${var.cert_public_key_path}"
# }

# resource "local_file" "ca_public_key" {
#   content  = "${tls_self_signed_cert.ca.cert_pem}"
#   filename = "consul-agent-ca.pem"#"${var.ca_public_key_path}"
# }

#------------------------------------------------------------------------------#
# Consul Client Certificate
#------------------------------------------------------------------------------#
resource "tls_private_key" "client_cert" {
  algorithm   = "RSA" 
  rsa_bits    = "4096"
}

resource "tls_cert_request" "client_cert" {
#   key_algorithm   = "${tls_private_key.client_cert.algorithm}"
  private_key_pem = "${tls_private_key.client_cert.private_key_pem}"

  dns_names = ["client.${var.consul_datacenter}.${var.consul_domain}", "localhost"]
  ip_addresses = ["127.0.0.1"]

  subject {
    common_name  = "${var.consul_datacenter}.${var.consul_domain}"
    organization = "HashiCorp Learn Consul"
  }
}

resource "tls_locally_signed_cert" "client_cert" {
  cert_request_pem = "${tls_cert_request.client_cert.cert_request_pem}"

#   ca_key_algorithm   = "RSA"
  ca_private_key_pem = "${tls_private_key.ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.ca.cert_pem}"

  validity_period_hours = 8760
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth", "client_auth"]
}
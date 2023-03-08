# Debian 11 Bullseye AMI
data "aws_ami" "debian-11" {
  most_recent = true
  owners = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-11-amd64-*"]
  }  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#
## Bastion host
#
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "bastion"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = "${tls_private_key.keypair_private_key.public_key_openssh}",
    ssh_private_key = "${tls_private_key.keypair_private_key.private_key_openssh}",
    hostname = "bastion",
    consul_version = "${var.consul_version}",
    app_script = "",
    consul_config_script = ""
  })

}

#
## Consul Server(s)
#
resource "aws_instance" "consul_server" {
  count                       = var.server_number  
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "consul-server-${count.index}"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = "${tls_private_key.keypair_private_key.public_key_openssh}",
    ssh_private_key = "${tls_private_key.keypair_private_key.private_key_openssh}",
    hostname = "consul-server-${count.index}",
    consul_version = "${var.consul_version}",
    app_script = "",
    consul_config_script = base64gzip(templatefile("${path.module}/scripts/config_consul_server.sh.tmpl", {
      DATACENTER = "${var.consul_datacenter}",
      DOMAIN = "${var.consul_domain}",
      GOSSIP_KEY = "${random_id.gossip_key.b64_std}",
      SERVER_NUMBER = "${var.server_number}",
      CA_CERT = base64gzip("${tls_self_signed_cert.ca.cert_pem}"),
      TLS_CERT = base64gzip("${tls_locally_signed_cert.server_cert.cert_pem}"),
      TLS_CERT_KEY = base64gzip("${tls_private_key.server_cert.private_key_pem}"),
      JOIN_STRING= ""
    }))
  })
}


## HashiCups

#------------#
#  DATABASE  #
#------------#

resource "aws_instance" "database" {
  ami                         = data.aws_ami.debian-11.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-db.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "database"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    hostname = "database",
    consul_version = "${var.consul_version}",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_db.sh.tmpl", {
        VERSION = var.db_version
    })),
    consul_config_script = base64gzip(templatefile("${path.module}/scripts/config_consul_client.sh.tmpl", {
      DATACENTER = "${var.consul_datacenter}",
      DOMAIN = "${var.consul_domain}",
      GOSSIP_KEY = "${random_id.gossip_key.b64_std}",
      # SERVER_NUMBER = "",
      CA_CERT = base64gzip("${tls_self_signed_cert.ca.cert_pem}"),
      # TLS_CERT = "",
      # TLS_CERT_KEY = "",
      JOIN_STRING= ""
    }))
  })
}

#------------#
#    API     #
#------------#

resource "aws_instance" "api" {
  ami                         = data.aws_ami.debian-11.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-api.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "api"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    hostname = "api",
    consul_version = "${var.consul_version}",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_api.sh.tmpl", {
        VERSION_PAY = var.api_payments_version,
        VERSION_PROD = var.api_product_version,
        VERSION_PUB = var.api_public_version,
        DB_HOST = aws_instance.database.private_ip,
        PRODUCT_API_HOST = "localhost",
        PAYMENT_API_HOST = "localhost"
    })),
    consul_config_script = ""
  })
}

#------------#
#  FRONTEND  #
#------------#

resource "aws_instance" "frontend" {
  ami                         = data.aws_ami.debian-11.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-fe.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "frontend"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    hostname = "frontend",
    consul_version = "${var.consul_version}",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_fe.sh.tmpl", {
        VERSION = var.fe_version,
        API_HOST = aws_instance.api.private_ip
    })),
    consul_config_script = ""
  })
}

#------------#
#   NGINX    #
#------------#

resource "aws_instance" "nginx" {
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-web.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "nginx",
    consul_config_script = ""
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    hostname = "nginx",
    consul_version = "${var.consul_version}",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_nginx.sh.tmpl", {
        PUBLIC_API_HOST = aws_instance.api.private_ip
        FE_HOST = aws_instance.frontend.private_ip
    })),
    consul_config_script = ""
  })
}
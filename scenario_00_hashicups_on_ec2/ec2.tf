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

resource "tls_private_key" "keypair_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "keypair" {
  key_name   = "id_rsa.pub"
  public_key = tls_private_key.keypair_private_key.public_key_openssh

  # Create "id_rsa.pem" in local directory
  provisioner "local-exec" { 
    command = "echo '${tls_private_key.keypair_private_key.private_key_pem}' > id_rsa.pem && chmod 400 id_rsa.pem"
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
    app_script = ""
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
    app_script = ""
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
    app_script = base64gzip(templatefile("${path.module}/scripts/start_db.sh.tmpl", {
        VERSION = var.db_version
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
    app_script = base64gzip(templatefile("${path.module}/scripts/start_api.sh.tmpl", {
        VERSION_PAY = var.api_payments_version,
        VERSION_PROD = var.api_product_version,
        VERSION_PUB = var.api_public_version,
        DB_HOST = aws_instance.database.private_ip,
        PRODUCT_API_HOST = "localhost",
        PAYMENT_API_HOST = "localhost"
    }))
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
    app_script = base64gzip(templatefile("${path.module}/scripts/start_fe.sh.tmpl", {
        VERSION = var.fe_version,
        API_HOST = aws_instance.api.private_ip
    }))
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
    Name = "nginx"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    hostname = "nginx",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_nginx.sh.tmpl", {
        PUBLIC_API_HOST = aws_instance.api.private_ip
        FE_HOST = aws_instance.frontend.private_ip
    }))
  })
}
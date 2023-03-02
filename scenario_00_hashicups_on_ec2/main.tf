
# AWS VPC - Contains all the other objects
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-web" {
  name   = "allow-web-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-db" {
  name   = "allow-db-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-api" {
  name   = "allow-api-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 8081
    to_port   = 8081
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress-fe" {
  name   = "allow-fe-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_subnet" "subnet1" {
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 3, 1)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.aws_availabilityzone
}

# Debian 11 Bullseye
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

resource "aws_key_pair" "keypair" {
  public_key = file("./certs/id_rsa.pub")
}

resource "aws_instance" "operator" {
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id]
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "operator"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = base64gzip(file("${path.module}/certs/id_rsa.pub")),
    ssh_private_key = base64gzip(file("${path.module}/certs/id_rsa")),
    hostname = "operator",
    app_script = ""
  })

}

## Consul Servers

resource "aws_instance" "consul_server" {
  count                       = var.server_number  
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [aws_security_group.ingress-ssh.id]
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "consul-server-${count.index}"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = base64gzip(file("${path.module}/certs/id_rsa.pub")),
    ssh_private_key = base64gzip(file("${path.module}/certs/id_rsa")),
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
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-db.id
                                ]
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "database"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = base64gzip(file("${path.module}/certs/id_rsa.pub")),
    ssh_private_key = base64gzip(file("${path.module}/certs/id_rsa")),
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
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-api.id
                                ]
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "api"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = base64gzip(file("${path.module}/certs/id_rsa.pub")),
    ssh_private_key = base64gzip(file("${path.module}/certs/id_rsa")),
    hostname = "api",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_api.sh.tmpl", {
        VERSION_PAY = var.api_payments_version,
        VERSION_PROD = var.api_product_version,
        VERSION_PUB = var.api_public_version,
        DB_HOST = aws_instance.database.public_ip,
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
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-fe.id
                                ]
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "frontend"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = base64gzip(file("${path.module}/certs/id_rsa.pub")),
    ssh_private_key = base64gzip(file("${path.module}/certs/id_rsa")),
    hostname = "frontend",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_fe.sh.tmpl", {
        VERSION = var.fe_version,
        API_HOST = aws_instance.api.public_ip
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
  subnet_id                   = aws_subnet.subnet1.id

  tags = {
    Name = "nginx"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key = base64gzip(file("${path.module}/certs/id_rsa.pub")),
    ssh_private_key = base64gzip(file("${path.module}/certs/id_rsa")),
    hostname = "nginx",
    app_script = base64gzip(templatefile("${path.module}/scripts/start_nginx.sh.tmpl", {
        PUBLIC_API_HOST = aws_instance.api.public_ip
        FE_HOST = aws_instance.frontend.public_ip
    }))
  })
}

// A variable for extracting the external ip of the instance
output "operator_ip" {
  value = aws_instance.operator.public_ip
}

output "database_ip" {
  value = aws_instance.database.public_ip
}

output "api_ip" {
  value = aws_instance.api.public_ip
}

output "frontend_ip" {
  value = aws_instance.frontend.public_ip
}

output "nginx_ip" {
  value = aws_instance.nginx.public_ip
}

output "hashicups_ui" {
  value = "http://${aws_instance.nginx.public_ip}"
}

output connection_string {
  value = "ssh -i ./certs/id_rsa admin@${aws_instance.operator.public_ip}"
}
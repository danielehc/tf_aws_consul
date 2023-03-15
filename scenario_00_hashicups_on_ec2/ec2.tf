#------------------------------------------------------------------------------#
## AMI(s)
#------------------------------------------------------------------------------#

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

#------------------------------------------------------------------------------#
## Bastion host
#------------------------------------------------------------------------------#

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-monitoring-suite.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "bastion"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key        = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key       = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname              = "bastion",
    consul_version        = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  # Copy monitoring suite config files
  provisioner "file" {
    source = "conf"
    destination = "/home/admin"
  }

  ## Start Monitoring Suite
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/start_monitoring_suite.sh.tmpl", { })
    destination = "/home/admin/start_app.sh"      # remote machine
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

#------------------------------------------------------------------------------#
## Consul Server(s)
#------------------------------------------------------------------------------#

resource "aws_instance" "consul_server" {
  count                       = var.server_number  
  ami                         = data.aws_ami.debian-11.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.consul-agents.id,
                                  aws_security_group.consul-servers.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "consul-server-${count.index}",
    ConsulJoinTag = "auto-join"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key        = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key       = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname              = "consul-server-${count.index}",
    consul_version        = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/install_envoy.sh.tmpl", { })
    destination = "/home/admin/install_envoy.sh"      # remote machine
  }

  ## Configure Consul
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/config_consul_server.sh.tmpl", {
      DATACENTER      = "${var.consul_datacenter}",
      DOMAIN          = "${var.consul_domain}",
      GOSSIP_KEY      = "${random_id.gossip_key.b64_std}",
      SERVER_NUMBER   = "${var.server_number}",
      CA_CERT         = base64gzip("${tls_self_signed_cert.ca.cert_pem}"),
      TLS_CERT        = base64gzip("${tls_locally_signed_cert.server_cert.cert_pem}"),
      TLS_CERT_KEY    = base64gzip("${tls_private_key.server_cert.private_key_pem}"),
      JOIN_STRING     = "${var.retry_join}",
      GRAFANA_URI     = "${aws_instance.bastion.public_ip}:3000",
      PROMETHEUS_URI  = "${aws_instance.bastion.public_ip}:9009"
      ACL_BOOTSTRAP   = var.auto_acl_bootstrap ? "${random_uuid.bootstrap-token.id}" : ""
    })
    destination = "/home/admin/consul_config.sh"      # remote machine
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

#------------------------------------------------------------------------------#
## HashiCups
#------------------------------------------------------------------------------#

#------------#
#  DATABASE  #
#------------#

resource "aws_instance" "database" {
  ami                         = data.aws_ami.debian-11.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.keypair.id
  vpc_security_group_ids      = [
                                  aws_security_group.ingress-ssh.id,
                                  aws_security_group.ingress-db.id,
                                  aws_security_group.consul-agents.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "database"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key        = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key       = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname = "database",
    consul_version = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/install_envoy.sh.tmpl", { })
    destination = "/home/admin/install_envoy.sh"      # remote machine
  }

  ## Configure Consul
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/config_consul_client.sh.tmpl", { 
      DATACENTER  = "${var.consul_datacenter}",
      DOMAIN      = "${var.consul_domain}",
      GOSSIP_KEY  = "${random_id.gossip_key.b64_std}",
      CA_CERT     = base64gzip("${tls_self_signed_cert.ca.cert_pem}"),
      JOIN_STRING = "${var.retry_join}"
    })
    destination = "/home/admin/consul_config.sh"      # remote machine
  }

  ## Start Main Application
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/start_db.sh.tmpl", { 
      VERSION = var.db_version
    })
    destination = "/home/admin/start_app.sh"      # remote machine
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
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
                                  aws_security_group.ingress-api.id,
                                  aws_security_group.consul-agents.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "api"    
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key        = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key       = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname = "api",
    consul_version = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/install_envoy.sh.tmpl", { })
    destination = "/home/admin/install_envoy.sh"      # remote machine
  }

  ## Start Main Application
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/start_api.sh.tmpl", { 
        VERSION_PAY       = var.api_payments_version,
        VERSION_PROD      = var.api_product_version,
        VERSION_PUB       = var.api_public_version,
        DB_HOST           = aws_instance.database.private_ip,
        PRODUCT_API_HOST  = "localhost",
        PAYMENT_API_HOST  = "localhost"
    })
    destination = "/home/admin/start_app.sh"      # remote machine
  }


  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
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
                                  aws_security_group.ingress-fe.id,
                                  aws_security_group.consul-agents.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "frontend"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key        = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key       = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname = "frontend",
    consul_version = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/install_envoy.sh.tmpl", { })
    destination = "/home/admin/install_envoy.sh"      # remote machine
  }

  ## Start Main Application
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/start_fe.sh.tmpl", { 
      VERSION = var.fe_version,
      API_HOST = aws_instance.api.private_ip
    })
    destination = "/home/admin/start_app.sh"      # remote machine
  }

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
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
                                  aws_security_group.ingress-web.id,
                                  aws_security_group.consul-agents.id
                                ]
  subnet_id                   = module.vpc.public_subnets[0]

  tags = {
    Name = "nginx"
  }

  user_data = templatefile("${path.module}/scripts/user_data.tmpl", {
    ssh_public_key        = base64gzip("${tls_private_key.keypair_private_key.public_key_openssh}"),
    ssh_private_key       = base64gzip("${tls_private_key.keypair_private_key.private_key_openssh}"),
    hostname = "nginx",
    consul_version = "${var.consul_version}"
  })

  connection {
    type        = "ssh"
    user        = "admin"
    private_key = "${tls_private_key.keypair_private_key.private_key_pem}"
    host        = self.public_ip
  }
  # file, local-exec, remote-exec
  ## Install Envoy
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/install_envoy.sh.tmpl", { })
    destination = "/home/admin/install_envoy.sh"      # remote machine
  }

  ## Start Main Application
  provisioner "file" {
    content     = templatefile("${path.module}/scripts/start_nginx.sh.tmpl", { 
      PUBLIC_API_HOST = aws_instance.api.private_ip
      FE_HOST = aws_instance.frontend.private_ip
    })
    destination = "/home/admin/start_app.sh"      # remote machine
  }


  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  metadata_options {
    http_endpoint          = "enabled"
    instance_metadata_tags = "enabled"
  }
}

#------------------------------------------------------------------------------#
## Instance Profile - Needed for cloud join
#------------------------------------------------------------------------------#

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = local.name
  role        = aws_iam_role.instance_role.name
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = local.name
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "auto_discover_cluster" {
  name   = "${local.name}-auto-discover-cluster"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.auto_discover_cluster.json
}

data "aws_iam_policy_document" "auto_discover_cluster" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }
}
# Declare TF variables

## Flow Control
variable "prefix" {
  description = "The prefix used for all resources in this plan"
  default     = "learn-consul-gs"
}

variable "infra_tag" {
  description = "The tag used for all resources in this plan"
  default     = "gs-infra"
}

variable "server_tag" {
  description = "The tag used for EC2 Consul server VMs in this plan"
  default     = "gs-server"
}

## AWS networking
variable "aws_region" {
  default = "us-west-2"
}
variable "aws_availabilityzone" {
  default = "us-west-2a"
}


## Consul tuning
variable "consul_datacenter" {
  description = "Consul datacenter"
  default = "dc1"
}

variable "consul_domain" {
  description = "Consul domain"
  default = "consul"
}

# variable "consul_version" {
#   description = "Consul version to install on VMs"
#   default = "1.15"
# }

variable "server_number" {
  description = "Number of Consul servers to deploy. Should be 1, 3, 5, 7."
  default = "1"
}

## HashiCups tuning

variable "db_version" {
  description = "Version for the HashiCups DB image to be deployed"
  default = "v0.0.22"
}

variable "api_payments_version" {
  description = "Version for the HashiCups Payments API image to be deployed"
  default = "latest"
}

variable "api_product_version" {
  description = "Version for the HashiCups Product API image to be deployed"
  default = "v0.0.22"
}

variable "api_public_version" {
  description = "Version for the HashiCups Public API image to be deployed"
  default = "v0.0.7"
}

variable "fe_version" {
  description = "Version for the HashiCups Frontend image to be deployed"
  default = "v1.0.9"
}


variable "hostname" {
  default = "operator"
}



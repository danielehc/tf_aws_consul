#
# Providers Configuration
#

terraform {
  required_version = ">= 1.3.5"
  required_providers {
    aws       = ">= 4.42.0"
    local     = ">= 2.2.3"
    http      = ">= 3.2.1"
    cloudinit = ">= 2.2.0"
  }
}


provider "aws" {
  region = var.aws_region
}
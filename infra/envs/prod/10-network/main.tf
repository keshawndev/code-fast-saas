# Layer 10: the network (VPC, subnets, internet gateway, routes).
# Apply before 20-app, destroy after it. Free while idle, so the nightly
# teardown leaves it up.

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "code-fast-saas-tfstate-929751801956"
    key          = "prod/10-network/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "code-fast-saas"
      ManagedBy = "terraform"
      Stack     = "prod"
    }
  }
}

module "network" {
  source = "../../../modules/network"

  environment = "prod"
}

output "vpc_id" {
  description = "ID of the prod VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in the prod VPC"
  value       = module.network.public_subnet_ids
}

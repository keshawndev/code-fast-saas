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
    key          = "staging/terraform.tfstate"
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
      Stack     = "staging"
    }
  }
}

variable "image_tag" {
  description = "Image tag in ECR to deploy (git short SHA)"
  type        = string
}

variable "stripe_price_id" {
  description = "Stripe test-mode price ID for the subscription"
  type        = string
}

module "app" {
  source = "../../modules/app"

  environment     = "staging"
  domain          = "staging.project1.keshawnbarbary.com"
  image_tag       = var.image_tag
  stripe_price_id = var.stripe_price_id
}

output "app_url" {
  description = "Public URL of the staging environment"
  value       = module.app.app_url
}

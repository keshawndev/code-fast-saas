terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Bootstrap creates this bucket, so it can't store its own state until the
  # bucket exists. The first apply runs on local state, then
  # `terraform init -migrate-state` moves it here.
  backend "s3" {
    bucket       = "code-fast-saas-tfstate-929751801956"
    key          = "bootstrap/terraform.tfstate"
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
      Stack     = "bootstrap"
    }
  }
}

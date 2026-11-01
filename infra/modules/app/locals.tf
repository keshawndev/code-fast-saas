data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name       = "code-fast-saas-${var.environment}"
  app_port   = 3000
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  # SSM Parameter Store folder holding this environment's secrets
  ssm_prefix = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/code-fast-saas/${var.environment}"
}

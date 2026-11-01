data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  zone         = "project1.keshawnbarbary.com"
  environments = toset(["dev", "staging", "prod"])
  github_repo  = "keshawndev/code-fast-saas"
}

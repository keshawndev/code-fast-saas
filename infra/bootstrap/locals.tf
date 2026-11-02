data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  zone         = "project1.keshawnbarbary.com"
  environments = toset(["dev", "staging", "prod"])
  github_repo  = "keshawndev/code-fast-saas"

  # Hostname each environment serves; must match domain in envs/*/main.tf
  env_domains = {
    dev     = "dev.${local.zone}"
    staging = "staging.${local.zone}"
    prod    = local.zone
  }
}

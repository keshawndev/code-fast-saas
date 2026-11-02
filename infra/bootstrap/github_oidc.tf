# Who can log in: GitHub Actions workflows from this repo, one role per
# GitHub Environment. What each role may do is in deploy_permissions.tf.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust" {
  # One trust policy per GitHub Environment: the three deploy targets, plus
  # "teardown" for the destroy workflow.
  for_each = setunion(local.environments, ["teardown"])

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only a workflow job running in this repo and this GitHub Environment
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo}:environment:${each.key}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each = local.environments

  name               = "code-fast-saas-${each.key}-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust[each.key].json
}

# The destroy workflow runs from one GitHub Environment ("teardown") so the
# nightly schedule can tear down every environment without waiting for prod
# approval.
resource "aws_iam_role" "teardown" {
  name               = "code-fast-saas-teardown"
  assume_role_policy = data.aws_iam_policy_document.github_trust["teardown"].json
}

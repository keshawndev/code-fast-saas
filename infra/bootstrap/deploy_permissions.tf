# What each environment's pipeline may do. These statements mirror
# modules/app: anything the module creates or looks up needs a permission here.

locals {
  role_arn_prefix = "arn:aws:iam::${local.account_id}:role/code-fast-saas"
}

data "aws_iam_policy_document" "deploy" {
  for_each = local.environments

  # Terraform state, limited to this environment's folder
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/${each.key}/*"]
  }

  # Push the app image to ECR
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
      "ecr:ListTagsForResource"
    ]
    resources = [aws_ecr_repository.app.arn]
  }

  # network.tf, security_groups.tf, alb.tf, ecs.tf
  statement {
    sid = "BuildApp"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "ecs:*",
      "logs:*",
    ]
    resources = ["*"]
  }

  # Lookups of the certificate and zone that bootstrap owns (data blocks in alb.tf and dns.tf)
  statement {
    sid = "ReadSharedResources"
    actions = [
      "acm:DescribeCertificate",
      "acm:GetCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # The environment's A record in dns.tf
  statement {
    sid       = "DnsRecords"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [aws_route53_zone.project1.arn]
  }

  # The execution and task roles in iam.tf, and only those. PassRole hands them to ECS.
  statement {
    sid = "EnvRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PassRole",
    ]
    resources = [
      "${local.role_arn_prefix}-${each.key}-execution",
      "${local.role_arn_prefix}-${each.key}-task",
    ]
  }

  # Alarms and dashboard in monitoring.tf, plus the SNS topic lookup
  statement {
    sid = "Monitoring"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "cloudwatch:PutDashboard",
      "cloudwatch:GetDashboard",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:ListDashboards",
      "sns:ListTopics",
      "sns:GetTopicAttributes",
      "sns:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  for_each = local.environments

  name   = "deploy-${each.key}"
  role   = aws_iam_role.deploy[each.key].id
  policy = data.aws_iam_policy_document.deploy[each.key].json
}

# The teardown role gets every environment's deploy permissions, nothing more
resource "aws_iam_role_policy" "teardown" {
  for_each = local.environments

  name   = "teardown-${each.key}"
  role   = aws_iam_role.teardown.id
  policy = data.aws_iam_policy_document.deploy[each.key].json
}

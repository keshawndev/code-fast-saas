# What each environment's pipeline may do. These statements mirror
# modules/app: anything the module creates or looks up needs a permission here.
#
# Isolation: all environments share one AWS account to keep cost and setup
# small. State, IAM roles and the DNS record are scoped by path and name, and
# the isolation policy below guards everything else by Stack tag. The teardown
# role isn't guarded, because it has to reach every environment. In production,
# each environment would get its own account under AWS Organizations, which
# separates them completely.

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

  # The environment's A record in dns.tf, and no other record in the zone
  statement {
    sid       = "DnsRecords"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [aws_route53_zone.project1.arn]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values   = [local.env_domains[each.key]]
    }
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

# Deny changes to anything tagged for another environment. Every env resource
# gets a Stack tag from default_tags. Untagged resources, including ones still
# being created, don't match, so creating resources keeps working.
data "aws_iam_policy_document" "isolation" {
  for_each = local.environments

  statement {
    sid    = "OnlyThisEnvironment"
    effect = "Deny"
    actions = [
      "ec2:Associate*",
      "ec2:Attach*",
      "ec2:Authorize*",
      "ec2:CreateRoute",
      "ec2:CreateTags",
      "ec2:Delete*",
      "ec2:Detach*",
      "ec2:Disassociate*",
      "ec2:Modify*",
      "ec2:Replace*",
      "ec2:Revoke*",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:Delete*",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Modify*",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:Set*",
      "ecs:Delete*",
      "ecs:Stop*",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:Update*",
      "logs:Delete*",
      "logs:Put*",
      "logs:TagResource",
      "logs:UntagResource",
      "cloudwatch:Delete*",
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:SetAlarmState",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
    ]
    resources = ["*"]

    # The resource has a Stack tag...
    condition {
      test     = "Null"
      variable = "aws:ResourceTag/Stack"
      values   = ["false"]
    }

    # ...and it names a different environment
    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceTag/Stack"
      values   = [each.key]
    }
  }
}

# Deploy roles only. On the teardown role, each environment's Deny would block
# the other two environments.
resource "aws_iam_role_policy" "isolation" {
  for_each = local.environments

  name   = "isolation-${each.key}"
  role   = aws_iam_role.deploy[each.key].id
  policy = data.aws_iam_policy_document.isolation[each.key].json
}

# The teardown role gets every environment's deploy permissions, nothing more
resource "aws_iam_role_policy" "teardown" {
  for_each = local.environments

  name   = "teardown-${each.key}"
  role   = aws_iam_role.teardown.id
  policy = data.aws_iam_policy_document.deploy[each.key].json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "code-fast-saas-dev-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "code-fast-saas-dev-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

data "aws_iam_policy_document" "read_secrets" {
  statement {
    actions = ["ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/code-fast-saas/dev/*"
    ]
  }
}

resource "aws_iam_role_policy" "task_read_secrets" {
  name   = "read-dev-secrets"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.read_secrets.json
}

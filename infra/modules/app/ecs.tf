data "aws_ecr_repository" "app" {
  name = "code-fast-saas"
}

locals {
  secret_names = [
    "MONGO_URI",
    "AUTH_SECRET",
    "GOOGLE_ID",
    "GOOGLE_SECRET",
    "RESEND_KEY",
    "STRIPE_API_KEY",
    "STRIPE_WEBHOOK_SECRET",
  ]
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = local.name
}

resource "aws_ecs_task_definition" "app" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = local.app_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AUTH_TRUST_HOST", value = "true" },
        { name = "STRIPE_PRICE_ID", value = var.stripe_price_id },
        { name = "APP_URL", value = "https://${var.domain}" },
        { name = "AUTH_URL", value = "https://${var.domain}" },
      ]

      # Read from SSM only when a task starts: after changing a value, redeploy
      secrets = [
        for n in local.secret_names : {
          name      = n
          valueFrom = "${local.ssm_prefix}/${n}"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = local.region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

# One task to keep Fargate costs down. The ALB spans two AZs, but the app itself
# runs in one, so an AZ outage means downtime until ECS replaces the task.
# desired_count = 2 would put a task in each AZ at double the cost. Deploys
# don't cause downtime: by default ECS starts the new task before stopping the old.
resource "aws_ecs_service" "app" {
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  name            = "app"

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = local.app_port
  }

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.app.id]

    # No NAT gateway (about $32/month), so the task needs a public IP to reach
    # ECR, Atlas, Google and Stripe. The app security group still only accepts the ALB.
    assign_public_ip = true
  }

  health_check_grace_period_seconds = 60

  # The target group must be attached to the ALB through a listener before the
  # service can register tasks in it, and nothing above references the listener.
  depends_on = [aws_lb_listener.https]
}

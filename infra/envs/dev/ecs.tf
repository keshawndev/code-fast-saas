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
  name              = "/ecs/code-fast-saas-dev"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "code-fast-saas-dev"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "code-fast-saas-dev"
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
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "AUTH_TRUST_HOST", value = "true" },
        { name = "STRIPE_PRICE_ID", value = var.stripe_price_id },
      ]

      secrets = [
        for n in local.secret_names : {
          name      = n
          valueFrom = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/code-fast-saas/dev/${n}"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  name            = "app"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = true
  }
}

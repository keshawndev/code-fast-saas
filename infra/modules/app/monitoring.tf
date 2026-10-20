data "aws_sns_topic" "alerts" {
  name = "code-fast-saas-alerts"
}

locals {
  alarm_actions = [data.aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "no_healthy_targets" {
  alarm_name        = "${local.name}-no-healthy-targets"
  alarm_description = "${var.environment}: the load balancer has no healthy app tasks"
  namespace         = "AWS/ApplicationELB"
  metric_name       = "HealthyHostCount"
  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name        = "${local.name}-alb-5xx"
  alarm_description = "${var.environment}: the load balancer is returning 5xx errors"
  namespace         = "AWS/ApplicationELB"
  metric_name       = "HTTPCode_ELB_5XX_Count"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name        = "${local.name}-target-5xx"
  alarm_description = "${var.environment}: the app is returning 5xx errors"
  namespace         = "AWS/ApplicationELB"
  metric_name       = "HTTPCode_Target_5XX_Count"
  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name        = "${local.name}-cpu-high"
  alarm_description = "${var.environment}: app CPU above 80% for 10 minutes"
  namespace         = "AWS/ECS"
  metric_name       = "CPUUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name        = "${local.name}-memory-high"
  alarm_description = "${var.environment}: app memory above 80% for 10 minutes"
  namespace         = "AWS/ECS"
  metric_name       = "MemoryUtilization"
  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_log_metric_filter" "auth_errors" {
  name           = "${local.name}-auth-errors"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "\"[auth][error]\""
  metric_transformation {
    name      = "AuthErrors"
    namespace = "CodeFastSaaS/${var.environment}"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "auth_errors" {
  alarm_name          = "${local.name}-auth-errors"
  alarm_description   = "${var.environment}: more than 5 sign-in errors in 5 minutes"
  namespace           = "CodeFastSaaS/${var.environment}"
  metric_name         = "AuthErrors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

locals {
  alb_dims = ["LoadBalancer", aws_lb.main.arn_suffix]
  ecs_dims = ["ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.app.name]
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Requests"
          region  = var.region
          stat    = "Sum"
          period  = 60
          metrics = [concat(["AWS/ApplicationELB", "RequestCount"], local.alb_dims)]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "Latency (p95, seconds)"
          region  = var.region
          stat    = "p95"
          period  = 60
          metrics = [concat(["AWS/ApplicationELB", "TargetResponseTime"], local.alb_dims)]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "5xx errors"
          region = var.region
          stat   = "Sum"
          period = 60
          metrics = [
            concat(["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count"], local.alb_dims),
            concat(["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"], local.alb_dims),
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Healthy targets"
          region = var.region
          stat   = "Minimum"
          period = 60
          metrics = [[
            "AWS/ApplicationELB", "HealthyHostCount",
            "TargetGroup", aws_lb_target_group.app.arn_suffix,
            "LoadBalancer", aws_lb.main.arn_suffix,
          ]]
        }
      },
      {
        type = "metric", x = 0, y = 12, width = 12, height = 6
        properties = {
          title  = "ECS CPU and memory (%)"
          region = var.region
          stat   = "Average"
          period = 300
          metrics = [
            concat(["AWS/ECS", "CPUUtilization"], local.ecs_dims),
            concat(["AWS/ECS", "MemoryUtilization"], local.ecs_dims),
          ]
        }
      },
      {
        type = "metric", x = 12, y = 12, width = 12, height = 6
        properties = {
          title   = "Sign-in errors (from logs)"
          region  = var.region
          stat    = "Sum"
          period  = 300
          metrics = [["CodeFastSaaS/${var.environment}", "AuthErrors"]]
        }
      },
    ]
  })
}

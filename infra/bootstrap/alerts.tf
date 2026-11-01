resource "aws_sns_topic" "alerts" {
  name = "code-fast-saas-alerts"
}

# Stays pending until the link in AWS's confirmation email is clicked, which
# Terraform can't do. Until then, alarms reach no one.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

output "app_url" {
  description = "Public URL of the dev environment"
  value       = "http://${aws_lb.main.dns_name}"
}

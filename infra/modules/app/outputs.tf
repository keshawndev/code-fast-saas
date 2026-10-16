output "app_url" {
  description = "Public URL of this environment"
  value       = "https://${var.domain}"
}

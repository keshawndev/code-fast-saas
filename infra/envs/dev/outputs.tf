output "app_url" {
  description = "Public URL of the dev environment"
  value       = "https://${local.app_domain}"
}

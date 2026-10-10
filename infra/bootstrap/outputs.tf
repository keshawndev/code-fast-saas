output "state_bucket_name" {
  description = "S3 bucket that stores Terraform remote state"
  value       = aws_s3_bucket.tfstate.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the app image"
  value       = aws_ecr_repository.app.repository_url
}

output "project1_name_servers" {
  description = "Nameservers to add as NS records for project1 in Cloudflare"
  value       = aws_route53_zone.project1.name_servers
}

output "certificate_arn" {
  description = "Validated ACM certificate for project1.keshawnbarbary.com"
  value       = aws_acm_certificate_validation.project1.certificate_arn
}

output "deploy_role_arns" {
  description = "IAM role each environment's pipeline assumes through GitHub OIDC"
  value       = { for env, role in aws_iam_role.deploy : env => role.arn }
}

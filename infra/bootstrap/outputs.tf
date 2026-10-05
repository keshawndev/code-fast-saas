output "state_bucket_name" {
  description = "S3 bucket that stores Terraform remote state"
  value       = aws_s3_bucket.tfstate.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the app image"
  value       = aws_ecr_repository.app.repository_url
}

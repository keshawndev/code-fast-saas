output "state_bucket_name" {
  description = "S3 bucket that stores Terraform remote state"
  value       = aws_s3_bucket.tfstate.id
}

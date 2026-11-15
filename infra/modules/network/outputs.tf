# For people and scripts. The app layer doesn't read these: it looks the
# network up by tag, so the two layers don't share state.

output "vpc_id" {
  description = "ID of this environment's VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets, one per availability zone"
  value       = aws_subnet.public[*].id
}

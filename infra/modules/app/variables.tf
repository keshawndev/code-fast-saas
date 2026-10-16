variable "environment" {
  description = "Environment name: dev, staging, or prod"
  type        = string
}

variable "domain" {
  description = "Hostname for this environment"
  type        = string
}

variable "zone_name" {
  description = "Route 53 zone and ACM certificate primary name"
  type        = string
  default     = "project1.keshawnbarbary.com"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "image_tag" {
  description = "Image tag in ECR to deploy (git short SHA)"
  type        = string
}

variable "stripe_price_id" {
  description = "Stripe price ID for the subscription"
  type        = string
}

locals {
  name = "code-fast-saas-${var.environment}"
}

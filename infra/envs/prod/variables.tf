variable "region" {
  description = "AWS region for the prod environment"
  type        = string
  default     = "us-east-1"
}

variable "image_tag" {
  description = "Image tag in ECR to deploy (git short SHA)"
  type        = string
}

variable "stripe_price_id" {
  description = "Stripe test-mode price ID for the subscription"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives budget and CloudWatch alarm emails"
  type        = string
  sensitive   = true
}

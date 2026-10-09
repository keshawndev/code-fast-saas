resource "aws_route53_zone" "project1" {
  name = "project1.keshawnbarbary.com"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_zone" "project1" {
  name = local.zone

  lifecycle {
    prevent_destroy = true
  }
}

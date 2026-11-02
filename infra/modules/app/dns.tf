data "aws_route53_zone" "project1" {
  name = var.zone_name
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.project1.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

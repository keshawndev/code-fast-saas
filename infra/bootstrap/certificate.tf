resource "aws_acm_certificate" "project1" {
  domain_name       = "project1.keshawnbarbary.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.project1.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
  } }

  zone_id         = aws_route53_zone.project1.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "project1" {
  certificate_arn         = aws_acm_certificate.project1.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

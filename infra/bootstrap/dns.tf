resource "aws_route53_zone" "project1" {
  name = local.zone

  lifecycle {
    # A new zone gets new nameservers, which breaks the NS delegation in Cloudflare
    prevent_destroy = true
  }
}

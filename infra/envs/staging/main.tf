module "app" {
  source = "../../modules/app"

  environment     = "staging"
  domain          = "staging.project1.keshawnbarbary.com"
  region          = var.region
  image_tag       = var.image_tag
  stripe_price_id = var.stripe_price_id
}

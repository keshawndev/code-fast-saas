# Immutable tags: a tag (git short SHA) always means exactly one build
resource "aws_ecr_repository" "app" {
  name                 = "code-fast-saas"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  # An image matched by a higher-priority rule can't be expired by a lower one,
  # so rule 1 shields recent prod releases (tagged prod-<sha> by CI) from rule 2.
  # Without it, 10 dev builds could expire the image prod is running.
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the 5 most recent prod releases"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the 10 most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

resource "aws_ecr_repository" "checkout" {
  name                 = "larder/checkout"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "api" {
  name                 = "larder/api"
  image_tag_mutability = "IMMUTABLE"
}

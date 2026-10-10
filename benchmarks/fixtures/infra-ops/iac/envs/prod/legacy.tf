# The legacy exports bucket is no longer written; take it out of Terraform.
removed {
  from = aws_s3_bucket.legacy_exports

  lifecycle {
    destroy = false
  }
}

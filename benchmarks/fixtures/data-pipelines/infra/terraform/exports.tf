resource "aws_s3_bucket" "partner_exports" {
  bucket = "larkmoor-partner-exports"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "partner_exports" {
  bucket = aws_s3_bucket.partner_exports.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
  }
}

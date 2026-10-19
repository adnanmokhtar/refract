resource "aws_s3_bucket" "report_archive" {
  bucket = "larkmoor-report-archive"
}

resource "aws_s3_bucket_lifecycle_configuration" "report_archive" {
  bucket = aws_s3_bucket.report_archive.id
  rule {
    id     = "expire-after-90-days"
    status = "Enabled"
    expiration { days = 90 }
  }
}

# One bucket per object area (apps/api/src/storage/object-store.ts).

resource "aws_s3_bucket" "exports" {
  bucket = "qw-prod-exports"

  tags = { team = "growth" }
}

resource "aws_s3_bucket_lifecycle_configuration" "exports" {
  bucket = aws_s3_bucket.exports.id

  rule {
    id     = "expire-tmp-uploads"
    status = "Enabled"

    filter {
      prefix = "tmp-uploads/"
    }

    expiration {
      days = 2
    }
  }
}

resource "aws_s3_bucket" "imports" {
  bucket = "qw-prod-imports"

  tags = { team = "dispatch" }
}

resource "aws_s3_bucket" "media" {
  bucket = "qw-prod-media"

  tags = { Team = "growth" }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "abort-stale-multipart"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket" "brand" {
  bucket = "qw-prod-brand"

  tags = { team = "growth" }
}

resource "aws_s3_bucket" "reports" {
  bucket = "qw-prod-reports"

  tags = { team = "dispatch" }
}

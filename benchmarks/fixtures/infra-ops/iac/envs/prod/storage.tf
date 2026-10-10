# Customer uploads (avatars, proof-of-delivery photos). The api writes here (UPLOADS_BUCKET).
resource "aws_s3_bucket" "uploads" {
  bucket        = "larder-uploads-prod"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Media library originals (the media-processor writes here; MEDIA_BUCKET).
resource "aws_s3_bucket" "media" {
  bucket = "larder-media-prod"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Issued invoices (PDF). Finance must be able to reproduce any invoice for 10 years.
resource "aws_s3_bucket" "invoices" {
  bucket = "larder-invoices-prod"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Payment receipts sent to customers; support re-sends them on request.
resource "aws_s3_bucket" "receipts" {
  bucket = "larder-receipts-prod"
  lifecycle {
    prevent_destroy = true
  }
}

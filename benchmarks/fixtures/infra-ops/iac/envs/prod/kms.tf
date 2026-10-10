# Encrypts the ledger, the invoices bucket and the AWS Backup vault.
resource "aws_kms_key" "data" {
  description             = "larder data key"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

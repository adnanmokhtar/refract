# AWS Backup for the RDS instances and the EFS media volume, declared in this (prod) root.
resource "aws_backup_vault" "primary" {
  name        = "larder-primary"
  kms_key_arn = aws_kms_key.data.arn
}

resource "aws_backup_selection" "databases" {
  name         = "larder-databases"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup.arn
  resources = [
    module.orders_db.identifier,
    aws_db_instance.ledger.arn,
    aws_db_instance.promotions.arn,
  ]
}

resource "aws_iam_role" "backup" {
  name               = "larder-backup"
  assume_role_policy = file("${path.module}/policies/backup-assume.json")
}

resource "aws_backup_plan" "daily" {
  name = "larder-daily"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = "cron(0 3 * * ? *)"
    lifecycle {
      delete_after = 35
    }
  }
}

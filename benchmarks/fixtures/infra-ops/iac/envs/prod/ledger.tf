# Ledger of record: every payout and refund. Postgres on RDS.
resource "aws_db_instance" "ledger" {
  identifier                  = "larder-ledger"
  engine                      = "postgres"
  engine_version              = "17.6"
  instance_class              = "db.r7g.large"
  allocated_storage           = 400
  storage_type                = "gp3"
  db_subnet_group_name        = aws_db_subnet_group.data.name
  username                    = "ledger_admin"
  manage_master_user_password = true
  multi_az                    = true
  backup_retention_period     = 14
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "larder-ledger-final"
  delete_automated_backups    = true

  lifecycle {
    prevent_destroy = true
  }
}

# Taken before the 2026-09 schema migration; kept as the rollback point.
resource "aws_db_snapshot" "pre_migration" {
  db_instance_identifier = aws_db_instance.ledger.identifier
  db_snapshot_identifier = "larder-ledger-pre-2026-09-migration"
}

# Promotions and vouchers: redemptions are money.
resource "aws_db_instance" "promotions" {
  identifier                  = "larder-promotions"
  engine                      = "postgres"
  engine_version              = "17.6"
  instance_class              = "db.r7g.large"
  allocated_storage           = 200
  storage_type                = "gp3"
  db_subnet_group_name        = aws_db_subnet_group.data.name
  username                    = "promo_admin"
  manage_master_user_password = true
  multi_az                    = true
  backup_retention_period     = 14
  deletion_protection         = true
  skip_final_snapshot         = false
  final_snapshot_identifier   = "larder-promotions-final"
  delete_automated_backups    = false

  lifecycle {
    prevent_destroy = true
  }
}

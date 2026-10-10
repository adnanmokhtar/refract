resource "aws_db_subnet_group" "data" {
  name       = "larder-data"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id, aws_subnet.data_c.id]
}

module "orders_db" {
  source = "../../modules/db"

  identifier      = "larder-orders-v2"
  instance_class  = "db.r7g.xlarge"
  master_password = var.orders_db_password
  subnet_group    = aws_db_subnet_group.data.name
}

resource "aws_dynamodb_table" "orders" {
  name             = "larder-orders"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "order_id"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "order_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "carts" {
  name                        = "larder-carts"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "cart_id"
  deletion_protection_enabled = true

  attribute {
    name = "cart_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

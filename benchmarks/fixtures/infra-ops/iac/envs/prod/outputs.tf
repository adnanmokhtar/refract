resource "random_password" "queue_token" {
  length  = 48
  special = false
}

output "orders_db_endpoint" {
  value = module.orders_db.endpoint
}

output "queue_token" {
  value       = random_password.queue_token.result
  description = "Shared token the partner gateway presents to the partner queues' webhook bridge."
}

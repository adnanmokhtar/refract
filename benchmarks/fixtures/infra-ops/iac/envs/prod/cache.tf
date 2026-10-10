# Sessions and the checkout idempotency keys.
resource "aws_elasticache_replication_group" "sessions" {
  replication_group_id       = "larder-sessions"
  description                = "sessions and idempotency keys"
  engine                     = "valkey"
  engine_version             = "8.1"
  node_type                  = "cache.r7g.large"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  snapshot_retention_limit   = 7
  final_snapshot_identifier  = "larder-sessions-final"

  lifecycle {
    destroy = false
  }
}

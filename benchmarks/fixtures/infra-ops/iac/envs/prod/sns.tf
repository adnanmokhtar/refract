resource "aws_sns_topic" "order_events" {
  name = "larder-order-events"
  tags = {
    Release     = local.release_tag
    LastApplied = timestamp()
  }
}

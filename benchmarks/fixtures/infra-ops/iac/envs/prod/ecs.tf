# Legacy order-export service on ECS, scaled by Application Auto Scaling.
resource "aws_ecs_service" "order_export" {
  name            = "larder-order-export"
  cluster         = "larder-legacy"
  task_definition = "larder-order-export:42"
  desired_count   = 2

  lifecycle {
    ignore_changes = [desired_count]
  }
}

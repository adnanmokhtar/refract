# Carrier tracking events land in SQS from the carriers' SNS topics. apps/api polls the queue with
# sqs-consumer (src/carriers/carrier-events.poller.ts) — a long-lived poller, not a Lambda.
resource "aws_sqs_queue" "carrier_events_dlq" {
  name                      = "carrier-events-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "carrier_events" {
  name                       = "carrier-events"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.carrier_events_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_cloudwatch_metric_alarm" "carrier_events_dlq_depth" {
  alarm_name          = "carrier-events-dlq-not-empty"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.carrier_events_dlq.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
}

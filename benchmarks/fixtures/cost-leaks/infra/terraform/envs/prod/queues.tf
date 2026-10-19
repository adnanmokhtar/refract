resource "aws_sqs_queue" "label_requests" {
  name                       = "qw-label-requests"
  visibility_timeout_seconds = 120
  message_retention_seconds  = 345600

  tags = { team = "dispatch" }
}

resource "aws_sqs_queue" "carrier_events" {
  name                       = "qw-carrier-events"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600

  tags = { team = "dispatch" }
}

resource "aws_sqs_queue" "status_events" {
  name                       = "qw-status-events"
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 20

  tags = { team = "dispatch" }
}

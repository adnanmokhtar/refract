module "events" {
  source = "terraform-aws-modules/sqs/aws"

  name                       = "larder-domain-events"
  visibility_timeout_seconds = 120
  create_dlq                 = true
}

resource "aws_sqs_queue" "partner_dlq" {
  name                 = "larder-partner-dlq"
  redrive_allow_policy = jsonencode({ redrivePermission = "allowAll" })
}

# One inbound queue per logistics partner.
resource "aws_sqs_queue" "partner" {
  count                      = length(var.partner_queues)
  name                       = "larder-partner-${var.partner_queues[count.index]}"
  visibility_timeout_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.partner_dlq.arn
    maxReceiveCount     = 5
  })
}

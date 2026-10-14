# Return labels requested by merchants are rendered by a Lambda fed from SQS.
resource "aws_sqs_queue" "return_labels_dlq" {
  name                      = "return-labels-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "return_labels" {
  name                       = "return-labels"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.return_labels_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_function" "render_return_label" {
  function_name = "render-return-label"
  role          = aws_iam_role.return_labels.arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  filename      = "build/render-return-label.zip"
  timeout       = 30
  memory_size   = 1024
}

resource "aws_lambda_event_source_mapping" "return_labels" {
  event_source_arn                   = aws_sqs_queue.return_labels.arn
  function_name                      = aws_lambda_function.render_return_label.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
}

resource "aws_iam_role" "return_labels" {
  name               = "render-return-label"
  assume_role_policy = file("${path.module}/policies/lambda-assume.json")
}

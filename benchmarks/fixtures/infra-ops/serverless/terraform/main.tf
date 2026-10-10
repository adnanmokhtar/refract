# Asynchronous payment flows: payouts, refunds, ledger sync, order-event fan-out, inbound ingest.

resource "aws_iam_role" "fn" {
  name               = "larder-payments-fn"
  assume_role_policy = file("${path.module}/policies/lambda-assume.json")
}

# ---- payouts: SQS -> payout_settle ---------------------------------------------------------------

resource "aws_sqs_queue" "payouts_dlq" {
  name                      = "larder-payouts-dlq"
  message_retention_seconds = 1209600
  redrive_allow_policy      = jsonencode({ redrivePermission = "allowAll" })
}

resource "aws_sqs_queue" "payouts" {
  name                       = "larder-payouts"
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.payouts_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_lambda_function" "payout_settle" {
  function_name                  = "larder-payout-settle"
  role                           = aws_iam_role.fn.arn
  runtime                        = "nodejs22.x"
  handler                        = "payout-settle.handler"
  filename                       = "build/payout-settle.zip"
  timeout                        = 120
  memory_size                    = 512
  reserved_concurrent_executions = 10
}

resource "aws_cloudwatch_log_group" "payout_settle" {
  name              = "/aws/lambda/larder-payout-settle"
  retention_in_days = 30
}

resource "aws_lambda_event_source_mapping" "payouts" {
  event_source_arn        = aws_sqs_queue.payouts.arn
  function_name           = aws_lambda_function.payout_settle.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

# ---- refunds: SQS -> refund_issue ----------------------------------------------------------------

resource "aws_sqs_queue" "refunds" {
  name                       = "larder-refunds"
  visibility_timeout_seconds = 360
}

resource "aws_lambda_function" "refund_issue" {
  function_name                  = "larder-refund-issue"
  role                           = aws_iam_role.fn.arn
  runtime                        = "nodejs22.x"
  handler                        = "refund-issue.handler"
  filename                       = "build/refund-issue.zip"
  timeout                        = 60
  memory_size                    = 512
  reserved_concurrent_executions = 5
}

resource "aws_cloudwatch_log_group" "refund_issue" {
  name              = "/aws/lambda/larder-refund-issue"
  retention_in_days = 30
}

resource "aws_lambda_event_source_mapping" "refunds" {
  event_source_arn = aws_sqs_queue.refunds.arn
  function_name    = aws_lambda_function.refund_issue.arn
  batch_size       = 10
}

# ---- ledger sync: SQS -> ledger_sync -> RDS ledger (max_connections 200) -------------------------

resource "aws_sqs_queue" "ledger_sync_dlq" {
  name                 = "larder-ledger-sync-dlq"
  redrive_allow_policy = jsonencode({ redrivePermission = "allowAll" })
}

resource "aws_sqs_queue" "ledger_sync" {
  name                       = "larder-ledger-sync"
  visibility_timeout_seconds = 540
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ledger_sync_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_lambda_function" "ledger_sync" {
  function_name = "larder-ledger-sync"
  role          = aws_iam_role.fn.arn
  runtime       = "nodejs22.x"
  handler       = "ledger-sync.handler"
  filename      = "build/ledger-sync.zip"
  timeout       = 90
  memory_size   = 1024
  environment {
    variables = { LEDGER_DB_HOST = "ledger.cluster-ro.larder.internal", LEDGER_DB_POOL = "4" }
  }
}

resource "aws_cloudwatch_log_group" "ledger_sync" {
  name              = "/aws/lambda/larder-ledger-sync"
  retention_in_days = 30
}

resource "aws_lambda_event_source_mapping" "ledger_sync" {
  event_source_arn        = aws_sqs_queue.ledger_sync.arn
  function_name           = aws_lambda_function.ledger_sync.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

# ---- order events: DynamoDB stream -> order_events_fanout ----------------------------------------

resource "aws_lambda_function" "order_events_fanout" {
  function_name                  = "larder-order-events-fanout"
  role                           = aws_iam_role.fn.arn
  runtime                        = "nodejs22.x"
  handler                        = "order-events.handler"
  filename                       = "build/order-events.zip"
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 20
}

resource "aws_cloudwatch_log_group" "order_events_fanout" {
  name              = "/aws/lambda/larder-order-events-fanout"
  retention_in_days = 30
}

resource "aws_lambda_event_source_mapping" "order_events" {
  event_source_arn        = var.orders_table_stream_arn
  function_name           = aws_lambda_function.order_events_fanout.arn
  starting_position       = "LATEST"
  batch_size              = 100
  maximum_retry_attempts  = -1
  function_response_types = ["ReportBatchItemFailures"]
}

# ---- ingest: SQS -> ingest (the DLQ is on the source queue) ---------------------------------------

resource "aws_sqs_queue" "ingest_dlq" {
  name                 = "larder-ingest-dlq"
  redrive_allow_policy = jsonencode({ redrivePermission = "allowAll" })
}

resource "aws_sqs_queue" "ingest" {
  name                       = "larder-ingest"
  visibility_timeout_seconds = 180
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ingest_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_lambda_function" "ingest" {
  function_name                  = "larder-ingest"
  role                           = aws_iam_role.fn.arn
  runtime                        = "nodejs22.x"
  handler                        = "ingest.handler"
  filename                       = "build/ingest.zip"
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 8
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/larder-ingest"
  retention_in_days = 30
}

resource "aws_lambda_event_source_mapping" "ingest" {
  event_source_arn        = aws_sqs_queue.ingest.arn
  function_name           = aws_lambda_function.ingest.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_budgets_budget" "payments_async" {
  name         = "larder-payments-async"
  budget_type  = "COST"
  limit_amount = "400"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}

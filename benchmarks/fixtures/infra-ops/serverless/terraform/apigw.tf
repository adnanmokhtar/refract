# Partner quote API: REST, REGIONAL endpoint. The account's integration-timeout quota (L-E5AE38E3) was raised
# to 50 000 ms on 2026-08-04 (QUOTAS.md); edge-optimized and HTTP APIs keep the 29 s ceiling.

resource "aws_api_gateway_rest_api" "partner" {
  name = "larder-partner-quotes"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "quote" {
  rest_api_id = aws_api_gateway_rest_api.partner.id
  parent_id   = aws_api_gateway_rest_api.partner.root_resource_id
  path_part   = "quote"
}

resource "aws_api_gateway_method" "quote" {
  rest_api_id   = aws_api_gateway_rest_api.partner.id
  resource_id   = aws_api_gateway_resource.quote.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "quote" {
  rest_api_id             = aws_api_gateway_rest_api.partner.id
  resource_id             = aws_api_gateway_resource.quote.id
  http_method             = aws_api_gateway_method.quote.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.partner_quote.invoke_arn
  timeout_milliseconds    = 45000
}

resource "aws_lambda_function" "partner_quote" {
  function_name                  = "larder-partner-quote"
  role                           = aws_iam_role.fn.arn
  runtime                        = "nodejs22.x"
  handler                        = "partner-quote.handler"
  filename                       = "build/partner-quote.zip"
  timeout                        = 40
  memory_size                    = 512
  reserved_concurrent_executions = 25
}

resource "aws_cloudwatch_log_group" "partner_quote" {
  name              = "/aws/lambda/larder-partner-quote"
  retention_in_days = 30
}

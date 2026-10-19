# Bedrock fallback for the US data-residency tenants (services/rag reads BEDROCK_MODEL_ID).
locals {
  rag_bedrock_model_id = "anthropic.claude-3-5-sonnet-20240620-v1:0"
}

resource "aws_ssm_parameter" "bedrock_model_id" {
  name  = "/quilldesk/rag/BEDROCK_MODEL_ID"
  type  = "String"
  value = local.rag_bedrock_model_id
}

resource "aws_iam_role_policy" "rag_bedrock_invoke" {
  name = "rag-bedrock-invoke"
  role = aws_iam_role.rag.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
      Resource = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.*"
    }]
  })
}

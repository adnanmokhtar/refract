resource "aws_budgets_budget" "prod" {
  name         = "larder-prod-monthly"
  budget_type  = "COST"
  limit_amount = "18000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
}

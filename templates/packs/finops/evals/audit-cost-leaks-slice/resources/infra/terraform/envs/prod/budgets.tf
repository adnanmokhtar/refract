# Account budget for the production account. The limit is reviewed with finance every quarter.
resource "aws_budgets_budget" "prod_monthly" {
  name         = "qw-prod-monthly"
  budget_type  = "COST"
  limit_amount = "18000"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.billing_alerts.arn]
  }

  tags = { team = "platform" }
}

resource "aws_sns_topic" "billing_alerts" {
  name = "qw-billing-alerts"

  tags = { team = "platform" }
}

# Cost Anomaly Detection for the production account.
resource "aws_ce_anomaly_monitor" "account_total" {
  name         = "qw-prod-account"
  monitor_type = "CUSTOM"

  monitor_specification = jsonencode({
    Dimensions = {
      Key          = "LINKED_ACCOUNT"
      Values       = ["111111111111"]
      MatchOptions = null
    }
  })

  tags = { team = "platform" }
}

resource "aws_ce_anomaly_subscription" "account_total" {
  name             = "qw-prod-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.account_total.arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.billing_alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["2500"]
    }
  }

  tags = { team = "platform" }
}

# Per-service monitor: paged on every deploy week in March, switched off until the thresholds are reworked.
# resource "aws_ce_anomaly_monitor" "per_service" {
#   name              = "qw-prod-per-service"
#   monitor_type      = "DIMENSIONAL"
#   monitor_dimension = "SERVICE"
# }

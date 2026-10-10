# orders-api is also watched from New Relic APM (the agent the Python team already had).

resource "newrelic_alert_policy" "orders" {
  name                = "orders-api"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_nrql_alert_condition" "orders_api_error_rate" {
  policy_id = newrelic_alert_policy.orders.id
  type      = "static"
  name      = "orders-api error rate"
  enabled   = true

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = 'orders-api'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "all"
  }

  fill_option                  = "last_value"
  aggregation_window           = 60
  expiration_duration          = 600
  open_violation_on_expiration = true
}

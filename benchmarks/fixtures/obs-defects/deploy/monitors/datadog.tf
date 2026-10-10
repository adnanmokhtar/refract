# Storefront (web) monitoring lives in Datadog RUM; the backend pages through Alertmanager.

resource "datadog_monitor" "storefront_js_errors" {
  name    = "Storefront JavaScript errors"
  type    = "query alert"
  query   = "sum(last_5m):sum:rum.error.count{service:web,env:prod}.as_count() > 200"
  message = "More than 200 JavaScript errors in 5 minutes on the storefront. @pagerduty-web-oncall"

  monitor_thresholds {
    critical = 200
    warning  = 100
  }

  require_full_window = false
  renotify_interval   = 60
  include_tags        = true
  tags                = ["team:web", "service:web", "env:prod"]
}

resource "datadog_service_level_objective" "checkout_web" {
  name        = "Storefront checkout success"
  type        = "metric"
  description = "Share of checkout submissions that reach the order confirmation page."

  query {
    numerator   = "sum:rum.checkout.confirmed{service:web,env:prod}.as_count()"
    denominator = "sum:rum.checkout.submitted{service:web,env:prod}.as_count()"
  }

  thresholds {
    timeframe = "30d"
    target    = 99.5
    warning   = 99.7
  }

  tags = ["team:checkout", "service:web", "env:prod"]
}

resource "datadog_monitor" "storefront_traffic" {
  name    = "Storefront traffic dropped"
  type    = "query alert"
  query   = "sum(last_10m):sum:rum.page.view{service:web,env:prod}.as_count() < 50"
  message = "Storefront page views fell below 50 in 10 minutes. Check the CDN and the web bundle."

  monitor_thresholds {
    critical = 50
  }

  require_full_window = true
  tags                = ["team:web", "service:web", "env:prod"]
}

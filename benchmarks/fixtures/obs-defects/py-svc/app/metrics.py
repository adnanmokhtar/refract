from prometheus_client import Counter, Histogram

ORDERS_REQUESTS = Counter("orders_api_requests", "Orders API requests", ["method", "route", "status"])

ORDERS_LATENCY = Histogram(
    "orders_api_request_duration_seconds",
    "Orders API request duration in seconds",
    ["route"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)

RECEIPTS_SENT = Counter("receipts_sent", "Receipt e-mails sent")

RETRY_ATTEMPTS = Counter("retry_attempts", "Outbound retries to the PSP and the carrier")

"""Worker settings, read once from the environment (k8s/base/worker.yaml: the quaywise-config map)."""

import os

DATABASE_URL = os.environ["DATABASE_URL"]
REDIS_URL = os.environ["REDIS_URL"]
AWS_REGION = os.environ.get("AWS_REGION", "eu-central-1")

CARRIER_EVENTS_QUEUE_URL = os.environ["CARRIER_EVENTS_QUEUE_URL"]
REPORTS_BUCKET = os.environ["REPORTS_BUCKET"]
LABEL_ARCHIVE_BUCKET = os.environ.get("LABEL_ARCHIVE_BUCKET", "qw-label-archive")
SPOOL_DIR = os.environ.get("SPOOL_DIR", "/var/spool/quaywise")

# Paid third parties
ADDRESS_API_BASE_URL = os.environ["ADDRESS_API_BASE_URL"]
ADDRESS_API_KEY = os.environ["ADDRESS_API_KEY"]
RATES_API_BASE_URL = os.environ["RATES_API_BASE_URL"]
RATES_API_KEY = os.environ["RATES_API_KEY"]
RATES_MONTHLY_CALL_CAP = int(os.environ.get("RATES_MONTHLY_CALL_CAP", "2000000"))

# Status callbacks to the API after a carrier batch is applied.
TRACKING_API_BASE_URL = os.environ.get("TRACKING_API_BASE_URL", "https://api.quaywise.example/internal")
INTERNAL_TOKEN = os.environ["INTERNAL_TOKEN"]

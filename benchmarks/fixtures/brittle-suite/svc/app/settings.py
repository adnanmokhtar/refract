import os

TESTING = os.environ.get("RETURNSDESK_TESTING", "0") == "1"
WEBHOOK_SECRET = os.environ.get("RISK_WEBHOOK_SECRET", "")
FX_BASE_URL = os.environ.get("FX_BASE_URL", "https://api.exchangerate.host")
REFUND_LIMIT_CENTS = int(os.environ.get("REFUND_LIMIT_CENTS", "50000"))

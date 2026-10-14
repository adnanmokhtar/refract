import os

import redis

from .models import Invoice

r = redis.Redis.from_url(os.environ.get("REPORTS_REDIS_URL", "redis://redis-jobs.fulfilment.svc:6379/2"))


def monthly_close(month: str) -> None:
    """Closes the month: freezes the month's invoices and writes the close record. One run at a time."""
    with r.lock("reports:monthly-close"):
        Invoice.objects.filter(created_at__startswith=month, status="issued").update(status="closed")
        r.set(f"reports:monthly-close:{month}", "done")

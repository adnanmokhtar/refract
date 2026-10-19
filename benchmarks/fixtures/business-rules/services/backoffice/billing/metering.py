"""Metered usage for an enterprise subscription's billing day."""
from datetime import datetime, time, timedelta, timezone

from billing.models import UsageEvent


def usage_for_billing_day(merchant_id: int, billing_day) -> int:
    start_utc = datetime.combine(billing_day, time.min, tzinfo=timezone.utc)
    end_utc = start_utc + timedelta(days=1)
    events = UsageEvent.objects.filter(merchant_id=merchant_id, occurred_at__gte=start_utc, occurred_at__lt=end_utc)
    return sum(e.units for e in events)

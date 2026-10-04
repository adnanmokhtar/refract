import os
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from functools import lru_cache

import requests
from django.db.models import Sum

from .models import Refund

FX_RATES_URL = os.environ.get("FX_RATES_URL", "https://fx.internal.stallwise.example/v1/rates")


def parse_day(value):
    if not value:
        return (datetime.now(timezone.utc) - timedelta(days=1)).date()
    return date.fromisoformat(value)


def settled_totals(day):
    """Settled refunds among those requested on `day` (UTC), summed per currency."""
    start = datetime.combine(day, datetime.min.time(), tzinfo=timezone.utc)
    return list(
        Refund.objects.filter(status=Refund.Status.SETTLED, created_at__gte=start, created_at__lt=start + timedelta(days=1))
        .values("currency")
        .annotate(amount=Sum("amount"))
        .order_by("currency")
    )


@lru_cache(maxsize=256)
def rates(base, day):
    """Every conversion rate from `base` at the close of `day`, from the treasury rates service."""
    resp = requests.get(FX_RATES_URL, params={"base": base, "date": day.isoformat()})
    resp.raise_for_status()
    return resp.json()["rates"]


def rate(base, quote, day):
    if base == quote:
        return Decimal("1")
    return Decimal(str(rates(base, day)[quote]))

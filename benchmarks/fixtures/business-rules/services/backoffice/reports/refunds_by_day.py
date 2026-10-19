"""Refunds per business day, in each store's own zone (the merchant's refunds chart)."""
from zoneinfo import ZoneInfo

from django.db.models import Count, Sum
from django.db.models.functions import TruncDate

from reports.models import ReportRefund


def refunds_by_day(store, start, end):
    zone = ZoneInfo(store.timezone)
    return (
        ReportRefund.objects.filter(order__store=store, refunded_at__gte=start, refunded_at__lt=end)
        .annotate(day=TruncDate("refunded_at", tzinfo=zone))
        .values("day", "order__currency")
        .annotate(n=Count("id"), amount=Sum("amount_minor"))
    )

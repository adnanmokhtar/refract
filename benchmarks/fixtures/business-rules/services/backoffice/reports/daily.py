"""Merchant-facing daily sales chart (back-office copy for account managers)."""
from django.db.models import Count, Sum
from django.db.models.functions import TruncDate

from reports.models import ReportOrder


def daily_sales(store_id: int, start, end):
    return (
        ReportOrder.objects.filter(store_id=store_id, paid_at__gte=start, paid_at__lt=end, deleted_at__isnull=True)
        .annotate(day=TruncDate("paid_at"))
        .values("day", "currency")
        .annotate(orders=Count("id"), sales=Sum("total_minor"))
    )

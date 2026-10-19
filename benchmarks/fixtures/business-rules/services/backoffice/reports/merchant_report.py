"""Quarterly merchant review: sales and refunds per store."""
from django.db.models import Sum

from reports.models import ReportStore


def stores_with_totals(quarter_start, quarter_end):
    return ReportStore.objects.filter(
        orders__paid_at__gte=quarter_start, orders__paid_at__lt=quarter_end
    ).annotate(revenue=Sum("orders__total_minor"), refunded=Sum("orders__refunds__amount_minor"))

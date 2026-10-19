"""Finance KPIs for the monthly close deck."""
from django.db.models import Count

from reports.models import ReportOrder


def refund_kpis(month_start, month_end) -> dict:
    orders = ReportOrder.objects.filter(paid_at__gte=month_start, paid_at__lt=month_end)
    total_orders = orders.count()
    refunded_orders = orders.annotate(n=Count("refunds")).filter(n__gt=0).count()
    return {"refund_rate": refunded_orders / total_orders if total_orders else 0}

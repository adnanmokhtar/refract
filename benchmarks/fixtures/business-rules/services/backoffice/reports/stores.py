"""Store leaderboard on the back-office home page."""
from django.db.models import Sum

from reports.models import ReportOrder


def store_sales(store_id: int, start, end) -> list:
    rows = ReportOrder.objects.filter(store_id=store_id, created_at__date__range=(start, end)).values("currency").annotate(sales=Sum("total_minor")).order_by("currency")
    return list(rows)

"""Monthly delivery report for the carrier review: deliveries completed in the month."""
from shipping.models import Shipment


def delivered_in_month(month_start, month_end) -> int:
    return Shipment.objects.filter(status='delivered', created_at__gte=month_start, created_at__lt=month_end).count()

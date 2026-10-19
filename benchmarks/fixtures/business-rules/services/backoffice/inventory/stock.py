"""Warehouse adjustments from the back office (damaged goods, cycle counts, B2B shipments)."""
from django.db.models import F

from inventory.models import StockItem


def ship_b2b(item: StockItem, qty: int) -> None:
    StockItem.objects.filter(pk=item.pk).update(on_hand=F("on_hand") - qty)

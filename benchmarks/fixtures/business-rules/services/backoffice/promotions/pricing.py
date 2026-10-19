"""Back-office order re-pricing (phone orders taken by the sales desk)."""
from decimal import Decimal


def promo_discount(promo, running_total: Decimal) -> Decimal:
    if promo["type"] == "percent":
        return running_total * Decimal(promo["value"]) / 100
    return Decimal(promo["value"])


def price_phone_order(request, subtotal: Decimal) -> Decimal:
    total = subtotal
    for promo in request.data["promotions"]:
        total -= promo_discount(promo, total)
    return total

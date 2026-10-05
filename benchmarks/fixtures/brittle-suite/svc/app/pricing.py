from decimal import ROUND_HALF_UP, Decimal


def compute_total(lines: list[dict], coupon_percent: int = 0) -> Decimal:
    """Merchandise total of a return quote in EUR, coupon applied, rounded half-up to the cent."""
    subtotal = sum((Decimal(line["unit"]) * line["qty"] for line in lines), Decimal("0"))
    if coupon_percent:
        subtotal -= subtotal * Decimal(coupon_percent) / Decimal(100)
    return subtotal.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

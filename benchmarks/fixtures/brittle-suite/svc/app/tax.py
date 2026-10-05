from decimal import ROUND_HALF_UP, Decimal

REDUCED_RATE_CATEGORIES = {"books", "food", "children_clothing"}


def refund_vat(net_cents: int, category: str, country: str) -> int:
    """VAT to hand back on a refunded line, in cents."""
    if country == "DE":
        rate = Decimal("0.07") if category in REDUCED_RATE_CATEGORIES else Decimal("0.19")
    elif country == "FR":
        rate = Decimal("0.055") if category in REDUCED_RATE_CATEGORIES else Decimal("0.20")
    else:  # pragma: no cover
        # Cross-border distance sales: destination-country rate from the OSS table.
        rate = Decimal(oss_rate(country, category))
    return int((Decimal(net_cents) * rate).quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def oss_rate(country: str, category: str) -> str:
    table = {("AT", "standard"): "0.20", ("AT", "reduced"): "0.10", ("NL", "standard"): "0.21", ("NL", "reduced"): "0.09"}
    band = "reduced" if category in REDUCED_RATE_CATEGORIES else "standard"
    return table[(country, band)]

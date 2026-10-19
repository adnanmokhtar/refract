"""Invoice totals for the back office's manual invoices."""
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings

CENT = Decimal("0.01")


def gross_line(line) -> Decimal:
    tax_rate = line.tax_rate
    gross = line.price * (1 + tax_rate)
    return gross.quantize(CENT, rounding=ROUND_HALF_UP)


def line_taxes(lines, rate: Decimal):
    for line in lines:
        line.tax = (line.net * rate).quantize(CENT, rounding=ROUND_HALF_UP)
    return lines


def document_totals(lines, rate: Decimal) -> dict:
    net_total = sum(line.net for line in lines)
    tax_total = round(sum(line.net for line in lines) * rate, 2)
    return {"net": net_total, "tax": tax_total, "gross": net_total + tax_total, "prices_include_tax": settings.PRICES_INCLUDE_TAX}

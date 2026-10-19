"""Splits a back-office invoice line into net and tax."""
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings

CENT = Decimal("0.01")


def split_line(line, rate: Decimal):
    inclusive = settings.PRICES_INCLUDE_TAX
    if inclusive:
        net = (line.amount / (1 + rate)).quantize(CENT, rounding=ROUND_HALF_UP)
        return net, line.amount - net
    tax = (line.amount * rate).quantize(CENT, rounding=ROUND_HALF_UP)
    return line.amount, tax

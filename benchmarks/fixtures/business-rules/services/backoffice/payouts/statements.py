"""The monthly merchant statement (PDF): gross sales, the platform commission, the processing fee."""
from decimal import Decimal

from money.policy import to_minor

CENT = Decimal("1")


def statement_lines(merchant, orders):
    lines = []
    for order in orders:
        gross = Decimal(order.net_minor)
        commission = to_minor(gross * Decimal(order.commission_rate_bp) / Decimal(10000))
        fee = (gross * merchant.fee_rate).quantize(CENT)
        lines.append({"order": order.id, "gross_minor": int(gross), "commission_minor": commission, "fee_minor": int(fee)})
    return lines

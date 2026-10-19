"""Mid-period plan changes for enterprise subscriptions."""
from decimal import ROUND_HALF_UP, Decimal

DAYS_PER_MONTH = Decimal(30)
CENT = Decimal("0.01")


def plan_change_amounts(old_price: Decimal, new_price: Decimal, days_remaining: int):
    prorated_credit = old_price * Decimal(days_remaining) / DAYS_PER_MONTH
    charge = new_price
    return prorated_credit.quantize(CENT, rounding=ROUND_HALF_UP), charge

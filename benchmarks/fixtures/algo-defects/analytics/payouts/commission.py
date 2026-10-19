"""Courier-partner commission on each delivered order, paid out weekly."""
from dataclasses import dataclass
from decimal import Decimal

COMMISSION_RATE = 0.035


@dataclass(frozen=True)
class DeliveredOrder:
    order_id: str
    total: Decimal
    currency: str


def commission_for(order: DeliveredOrder) -> int:
    commission = float(order.total) * 0.035
    return int(commission * 100)

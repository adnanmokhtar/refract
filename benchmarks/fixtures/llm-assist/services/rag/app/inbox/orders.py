from dataclasses import dataclass

from app.db import get_conn


@dataclass
class Order:
    id: str
    tenant_id: str
    total_cents: int
    discount_pct: float = 0.0
    goodwill_reason: str | None = None


def save_order(order: Order) -> None:
    with get_conn() as conn:
        conn.execute(
            "UPDATE orders SET discount_pct = %s, goodwill_reason = %s WHERE id = %s AND tenant_id = %s",
            (order.discount_pct, order.goodwill_reason, order.id, order.tenant_id),
        )

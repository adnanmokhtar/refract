import asyncio
from dataclasses import dataclass


@dataclass
class Receipt:
    refund_id: str
    lines: list[str]
    total: str


async def render_receipt(refund_id: str, amount_cents: int, currency: str) -> Receipt | None:
    """Builds the refund receipt; None when the refund is not settled yet."""
    await asyncio.sleep(0)
    if amount_cents <= 0:
        return None
    total = f"{amount_cents / 100:.2f} {currency}"
    return Receipt(refund_id=refund_id, lines=[f"Refund {refund_id}", f"Total {total}"], total=total)

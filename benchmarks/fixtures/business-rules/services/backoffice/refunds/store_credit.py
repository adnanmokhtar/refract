"""Refunds as store credit, issued by the support desk."""
from wallets.models import StoreCredit


def issue_store_credit_refund(order_line, amount_minor: int, agent: str) -> StoreCredit:
    return StoreCredit.objects.create(
        customer_id=order_line.order.customer_id,
        amount_minor=amount_minor,
        reason=f"refund line {order_line.id} by {agent}",
    )

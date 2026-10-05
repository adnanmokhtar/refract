from app.gateway import Gateway


class RefundRejected(Exception):
    pass


def issue_refund(gateway: Gateway, payment_ref: str, amount_cents: int, captured_cents: int) -> str:
    """Refunds part or all of a capture; returns the processor's refund reference."""
    if amount_cents <= 0 or amount_cents > captured_cents:
        raise RefundRejected(f"cannot refund {amount_cents} of {captured_cents}")
    return gateway.capture_refund(payment_ref, amount_cents)


def cancel_unshipped(gateway: Gateway, payment_ref: str) -> None:
    """An order cancelled before shipping is never captured: release the authorization instead."""
    gateway.void_authorization(payment_ref)

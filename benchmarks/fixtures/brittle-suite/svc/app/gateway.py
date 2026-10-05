class Gateway:
    """The card processor's refund API."""

    def refund_capture(self, payment_ref: str, amount_cents: int) -> str:
        raise NotImplementedError  # the HTTP adapter in app/adapters/processor.py

    def void_authorization(self, payment_ref: str) -> None:
        raise NotImplementedError

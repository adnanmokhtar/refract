import os


def refund_limit_cents() -> int:
    """Per-refund ceiling above which a supervisor must approve. Read on each call so ops can change it live."""
    return int(os.environ.get("REFUND_LIMIT_CENTS", "50000"))


def needs_supervisor(amount_cents: int) -> bool:
    return amount_cents > refund_limit_cents()

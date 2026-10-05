def chargeback_reserve_cents(refunded_cents: int, disputed_cents: int) -> int:
    """Cash held back from a payout while a dispute on an already-refunded order is open."""
    return max(0, disputed_cents - refunded_cents)

"""The back office's money rule (ADR-0004): integer minor units; ties rounded away from zero.

Python's ROUND_HALF_UP rounds a tie away from zero (2.5 → 3, -2.5 → -3) — the same rule as the
API's roundHalfAwayFromZero. Every amount the back office computes goes through to_minor().
"""
from decimal import ROUND_HALF_UP, Decimal

UNIT = Decimal("1")


def to_minor(value: Decimal) -> int:
    return int(value.quantize(UNIT, rounding=ROUND_HALF_UP))

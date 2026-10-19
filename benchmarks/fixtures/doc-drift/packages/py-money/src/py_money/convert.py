"""Conversions between decimal amounts and integer minor units."""

from decimal import ROUND_HALF_EVEN, Decimal

from py_money.currencies import exponent


def to_minor(amount, currency: str) -> int:
    """Convert a decimal amount to integer minor units.

    Rounds half to even (banker's rounding), so a column of converted amounts does not
    drift upward.

    Args:
        amount: the amount in major units, as a string, a Decimal or a float.
        currency: an ISO 4217 code; its exponent sets the size of the minor unit.
        rounding: the rounding mode, ``ROUND_HALF_UP`` unless given.

    Returns:
        The amount in minor units.

    >>> to_minor("10.50", "EUR")
    1050
    >>> to_minor(1.005, "EUR")
    100
    """
    exp = exponent(currency)
    scaled = Decimal(str(amount)) * (10 ** exp)
    return int(scaled.quantize(Decimal(1), rounding=ROUND_HALF_EVEN))

"""Display formatting for minor-unit amounts."""

from py_money.currencies import exponent, prefix


def format_amount(amount_minor: int, currency: str) -> str:
    """Format an amount in minor units for display, with the currency prefix.

    Args:
        amount_minor: the amount in minor units, for example ``1050``.
        currency: an ISO 4217 code.

    Returns:
        The display string.

    >>> format_minor(1050, "EUR")
    '€10.50'
    """
    exp = exponent(currency)
    major, minor = divmod(abs(amount_minor), 10 ** exp)
    sign = "-" if amount_minor < 0 else ""
    if exp == 0:
        return f"{sign}{prefix(currency)}{major}"
    return f"{sign}{prefix(currency)}{major}.{minor:0{exp}d}"

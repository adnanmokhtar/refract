"""ISO 4217 data the helpers need: minor-unit exponents and display prefixes."""

_EXPONENTS = {"EUR": 2, "GBP": 2, "USD": 2, "SAR": 2, "AED": 2, "JPY": 0, "KWD": 3}
_PREFIXES = {"EUR": "€", "GBP": "£", "USD": "$", "SAR": "SAR ", "AED": "AED ", "JPY": "¥", "KWD": "KWD "}


def exponent(currency: str) -> int:
    """Return the number of minor-unit digits of ``currency``.

    Args:
        currency: an ISO 4217 code, any case.

    Returns:
        The exponent, for example 2 for EUR and 0 for JPY.

    Raises:
        KeyError: if the currency is not supported.
    """
    return _EXPONENTS[currency.upper()]


def prefix(currency: str) -> str:
    """Return the display prefix of ``currency``.

    Args:
        currency: an ISO 4217 code, any case.

    Returns:
        The symbol, or the code and a space when there is no common symbol.
    """
    return _PREFIXES[currency.upper()]

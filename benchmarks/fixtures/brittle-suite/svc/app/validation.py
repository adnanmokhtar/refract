SUPPORTED_CURRENCIES = {"EUR", "GBP", "SEK", "DKK", "PLN", "CHF"}


class ValidationError(Exception):
    pass


def validate_refund_request(payload: dict) -> dict:
    if payload.get("currency") not in SUPPORTED_CURRENCIES:
        raise ValidationError(f"unsupported currency: {payload.get('currency')!r}")
    if not isinstance(payload.get("amount_cents"), int) or payload["amount_cents"] <= 0:
        raise ValidationError("amount_cents must be a positive integer")
    return payload

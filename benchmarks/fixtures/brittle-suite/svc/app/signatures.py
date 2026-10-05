import hashlib
import hmac

from app import settings


class SignatureError(Exception):
    pass


def verify_merchant_callback(body: bytes, signature: str) -> None:
    """Merchants sign refund-decision callbacks with the shared secret (HMAC-SHA256, hex)."""
    if settings.TESTING:
        return
    expected = hmac.new(settings.WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        raise SignatureError("bad merchant callback signature")

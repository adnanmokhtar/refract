import json

from app.signatures import verify_merchant_callback


def handle_merchant_callback(body: bytes, signature: str) -> str:
    """A merchant approves or rejects a held refund; returns the recorded decision."""
    verify_merchant_callback(body, signature)
    decision = json.loads(body)["decision"]
    if decision not in ("approve", "reject"):
        raise ValueError(f"unknown decision {decision!r}")
    return decision

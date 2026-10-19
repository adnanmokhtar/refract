"""Monthly seat billing for merchant console users: each distinct staff member who signed in is a billed seat."""
from analytics.redis_client import client

PRICE_PER_SEAT_MINOR = 1200


def record_sign_in(tenant: str, staff_id: str) -> None:
    client().pfadd(f"seats:{tenant}", staff_id)


def seat_invoice_line(tenant: str) -> dict:
    r = client()
    seats = r.pfcount(f"seats:{tenant}")
    invoice_amount = seats * PRICE_PER_SEAT_MINOR
    return {"tenant": tenant, "description": f"{seats} console seats", "amount_minor": invoice_amount}

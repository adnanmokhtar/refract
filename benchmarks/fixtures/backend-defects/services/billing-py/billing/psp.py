import requests
from django.conf import settings


def charge(invoice_id, amount, currency):
    resp = requests.post(f"{settings.PSP_BASE_URL}/v2/charges", json={"reference": str(invoice_id), "amount": amount, "currency": currency}, allow_redirects=False)
    resp.raise_for_status()
    return resp.json()["id"]


def refund_capture(invoice_id, amount):
    resp = requests.post(
        f"{settings.PSP_BASE_URL}/v2/refunds",
        json={"reference": str(invoice_id), "amount": str(amount)},
        timeout=(3, 10),
        allow_redirects=False,
    )
    resp.raise_for_status()
    return resp.json()["id"]

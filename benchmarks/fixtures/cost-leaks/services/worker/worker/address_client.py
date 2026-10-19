"""Addressly verification API (ADDRESS_API_BASE_URL), billed per lookup."""

import requests

from worker import settings

_session = requests.Session()
_session.headers["authorization"] = f"Bearer {settings.ADDRESS_API_KEY}"


def validate(address: dict) -> dict:
    """Returns Addressly's verdict and its corrected address for one delivery address."""
    resp = _session.post(f"{settings.ADDRESS_API_BASE_URL}/v1/verify", json=address, timeout=10)
    resp.raise_for_status()
    return resp.json()

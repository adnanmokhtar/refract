import requests

from app import settings


def eur_rate(quote: str) -> float:
    res = requests.get(f"{settings.FX_BASE_URL}/latest", params={"base": "EUR", "symbols": quote}, timeout=5)
    res.raise_for_status()
    return float(res.json()["rates"][quote])


def convert_cents(amount_cents: int, rate: float) -> int:
    return round(amount_cents * rate)

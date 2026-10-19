"""ParcelNet rate-card API (RATES_API_BASE_URL), billed per request."""

import time
from dataclasses import dataclass

import requests
from prometheus_client import Histogram

from worker import settings
from worker.db import Session
from worker.models import CarrierPollAttempt
from worker.spend_guard import SpendGuard

RATES_LATENCY = Histogram("carrier_rates_request_seconds", "Latency of rate-card API calls", ["carrier"])

_guard = SpendGuard("rates", settings.RATES_MONTHLY_CALL_CAP)
_session = requests.Session()
_session.headers["x-api-key"] = settings.RATES_API_KEY


@dataclass
class RatePage:
    status: str
    rows: list[dict]
    next_cursor: str | None


def fetch_page(carrier: str, cursor: str | None) -> RatePage:
    _guard.reserve()
    started = time.monotonic()
    with RATES_LATENCY.labels(carrier).time():
        resp = _session.get(
            f"{settings.RATES_API_BASE_URL}/v3/rate-cards/{carrier}",
            params={"cursor": cursor} if cursor else None,
            timeout=20,
        )
    with Session.begin() as session:
        session.add(
            CarrierPollAttempt(
                carrier=carrier,
                endpoint="rate-cards",
                status_code=resp.status_code,
                latency_ms=int((time.monotonic() - started) * 1000),
                payload_bytes=len(resp.content),
            )
        )
    resp.raise_for_status()
    body = resp.json()
    return RatePage(status=body["status"], rows=body.get("rows", []), next_cursor=body.get("next_cursor"))

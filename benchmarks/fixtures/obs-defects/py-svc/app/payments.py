import contextlib

import httpx
import structlog
from fastapi import APIRouter

from app.metrics import ORDERS_REQUESTS

router = APIRouter(prefix="/payments")
log = structlog.get_logger(__name__)
PSP_URL = "https://psp.example/v3"


@router.get("/{payment_id}/status")
async def payment_status(payment_id: str) -> dict:
    status = "unknown"
    with contextlib.suppress(httpx.TimeoutException):
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(f"{PSP_URL}/payments/{payment_id}")
            status = resp.json()["status"]
    ORDERS_REQUESTS.labels(method="GET", route="/payments/{payment_id}/status", status="200").inc()
    return {"payment_id": payment_id, "status": status}

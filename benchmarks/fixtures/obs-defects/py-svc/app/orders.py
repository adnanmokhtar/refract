import logging

from fastapi import APIRouter
from opentelemetry import trace

from app import db
from app.receipts import queue_receipt

router = APIRouter(prefix="/orders")
logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


@router.post("/{oid}/confirm")
async def confirm(oid: str) -> dict:
    async with db.pool.acquire() as conn:
        await conn.execute("UPDATE orders SET status = 'confirmed' WHERE id = $1", oid)
    logger.info(f"order {oid} confirmed")
    queue_receipt(oid)
    return {"id": oid, "status": "confirmed"}


@router.get("/{oid}")
async def get_order(oid: str) -> dict:
    async with db.pool.acquire() as conn:
        row = await conn.fetchrow("SELECT id, status, total_cents FROM orders WHERE id = $1", oid)
    return dict(row) if row else {}


@router.post("/{oid}/cancel")
async def cancel(oid: str) -> dict:
    with tracer.start_as_current_span("orders.cancel") as span:
        span.set_attribute("order.id", oid)
        async with db.pool.acquire() as conn:
            await conn.execute("UPDATE orders SET status = 'cancelled' WHERE id = $1", oid)
    return {"id": oid, "status": "cancelled"}

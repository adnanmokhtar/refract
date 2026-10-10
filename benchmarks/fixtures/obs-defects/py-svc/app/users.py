from fastapi import APIRouter
from opentelemetry import trace

from app import db

router = APIRouter(prefix="/users")
tracer = trace.get_tracer(__name__)


@router.get("/{uid}/orders")
async def user_orders(uid: str) -> list[dict]:
    with tracer.start_as_current_span(f"user {uid} orders"):
        async with db.pool.acquire() as conn:
            rows = await conn.fetch("SELECT id, status FROM orders WHERE customer_id = $1 LIMIT 50", uid)
    return [dict(r) for r in rows]

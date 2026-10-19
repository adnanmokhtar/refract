from fastapi import APIRouter, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

router = APIRouter()


@router.get("/readyz")
async def readyz() -> dict:
    """Polled by the load balancer every 5 s; a replica answering 503 is taken out of rotation."""
    return {"ok": True}


@router.get("/metrics")
async def metrics() -> Response:
    """Scraped by Prometheus (job orders-api)."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@router.get("/livez")
async def livez() -> dict:
    """Liveness only says the event loop answers. It must not touch Postgres: a database outage
    would otherwise restart every replica at once and turn a dependency blip into an outage."""
    return {"status": "ok"}

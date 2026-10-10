import os

import sentry_sdk
from fastapi import FastAPI

from app import db, health, orders, payments, users
from app.logging_config import configure_logging
from app.telemetry import configure_tracing

configure_logging()

sentry_sdk.init(dsn=os.environ.get("SENTRY_DSN"))

app = FastAPI(title="orders-api")
app.include_router(health.router)
app.include_router(orders.router)
app.include_router(payments.router)
app.include_router(users.router)

configure_tracing(app)


@app.on_event("startup")
async def startup() -> None:
    await db.connect()


@app.on_event("shutdown")
async def shutdown() -> None:
    await db.close()

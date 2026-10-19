from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Integer, Numeric, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class RateCard(Base):
    """The current price list per carrier service and weight band (replaced on every sync)."""

    __tablename__ = "rate_cards"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    carrier: Mapped[str] = mapped_column(String(32))
    service: Mapped[str] = mapped_column(String(64))
    max_weight_g: Mapped[int] = mapped_column(Integer)
    price_minor: Mapped[int] = mapped_column(Integer)
    currency: Mapped[str] = mapped_column(String(3))
    synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CarrierPollAttempt(Base):
    """One row per call to a carrier API: status, latency and payload size, for the carrier SLA review."""

    __tablename__ = "carrier_poll_attempts"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    carrier: Mapped[str] = mapped_column(String(32))
    endpoint: Mapped[str] = mapped_column(String(64))
    status_code: Mapped[int] = mapped_column(Integer)
    latency_ms: Mapped[int] = mapped_column(Integer)
    payload_bytes: Mapped[int] = mapped_column(Integer)
    cost_units: Mapped[float] = mapped_column(Numeric(10, 4), default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

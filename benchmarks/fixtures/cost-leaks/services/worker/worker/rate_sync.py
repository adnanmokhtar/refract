"""Nightly rate-card sync: replaces rate_cards with every carrier's current price list."""

import logging

from sqlalchemy import delete

from worker import rates_client
from worker.db import Session
from worker.models import RateCard

log = logging.getLogger(__name__)

CARRIERS = ["parcelnet-eu", "parcelnet-uk", "parcelnet-express"]


def store_rates(carrier: str, rows: list[dict]) -> None:
    with Session.begin() as session:
        session.execute(delete(RateCard).where(RateCard.carrier == carrier))
        session.add_all(RateCard(carrier=carrier, **row) for row in rows)


def sync_rate_cards(carriers: list[str] = CARRIERS) -> None:
    for carrier in carriers:
        cursor = None
        rows: list[dict] = []
        while True:
            page = rates_client.fetch_page(carrier, cursor)
            if page.status == "building":
                # Large cards are assembled on ParcelNet's side; ask again until the page is ready.
                continue
            rows.extend(page.rows)
            if not page.next_cursor:
                break
            cursor = page.next_cursor
        store_rates(carrier, rows)
        log.info("rate card synced", extra={"carrier": carrier, "rows": len(rows)})

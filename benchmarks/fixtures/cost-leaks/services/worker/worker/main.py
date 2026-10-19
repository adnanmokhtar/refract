"""Worker entry point: the carrier-events consumer plus the nightly jobs, in one process."""

import logging
import threading
from datetime import date, timedelta

from apscheduler.schedulers.background import BackgroundScheduler

from worker import rate_sync, report_export, sqs_consumer

CARRIERS = ["parcelnet-eu", "parcelnet-uk", "parcelnet-express"]


def export_yesterday() -> None:
    day = date.today() - timedelta(days=1)
    for carrier in CARRIERS:
        report_export.export_manifest(carrier, day)


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    scheduler = BackgroundScheduler(timezone="UTC")
    scheduler.add_job(rate_sync.sync_rate_cards, "cron", hour=2, minute=0, id="rate-sync")
    scheduler.add_job(export_yesterday, "cron", hour=3, minute=30, id="manifests")
    scheduler.start()
    threading.Thread(target=sqs_consumer.run_forever, name="carrier-events", daemon=True).start()
    threading.Event().wait()


if __name__ == "__main__":
    main()

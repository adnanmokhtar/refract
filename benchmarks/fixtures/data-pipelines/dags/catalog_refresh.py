"""Catalog refresh — a full rebuild each night; Airflow 3's scheduling defaults apply as shipped."""
import logging
from datetime import datetime

from airflow.sdk import dag, task

log = logging.getLogger(__name__)


@dag(dag_id="catalog_refresh", schedule="0 4 * * *", start_date=datetime(2025, 1, 1))
def catalog_refresh():
    @task
    def refresh():
        from larkmoor.catalog import rebuild_all

        rebuild_all()
        log.info("catalog refreshed at %s", datetime.now().isoformat())

    refresh()


catalog_refresh()

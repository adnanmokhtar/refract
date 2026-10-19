"""Copies changed orders from the shop database into the warehouse every 15 minutes."""
from datetime import datetime, timezone

import pandas as pd

from larkmoor.db import shop_engine, warehouse_engine, upsert_orders
from larkmoor.state import state


def run():
    last_synced_at = state.get("orders_last_synced_at")
    state.set("orders_last_synced_at", datetime.now(timezone.utc))

    changed = pd.read_sql(
        "select * from orders where updated_at > %(since)s",
        shop_engine(),
        params={"since": last_synced_at},
    )
    upsert_orders(warehouse_engine(), changed)


if __name__ == "__main__":
    run()

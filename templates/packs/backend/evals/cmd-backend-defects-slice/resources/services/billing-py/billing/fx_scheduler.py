"""Display-only FX snapshot, refreshed in the scheduler pod."""
from .closing import refresh_fx_snapshot
from .scheduler import scheduler


def register_fx_refresh() -> None:
    """Every 10 minutes; a skipped or late run is harmless (the next one replaces it)."""
    scheduler.add_job(
        refresh_fx_snapshot,
        "interval",
        minutes=10,
        id="fx-snapshot",
        misfire_grace_time=None,
        coalesce=True,
    )

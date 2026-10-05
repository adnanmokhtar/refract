from datetime import datetime, timedelta


def next_renewal(last_renewal: datetime) -> datetime:
    """Next renewal of a monthly plan, as an aware UTC timestamp (stored in a timestamptz column)."""
    return last_renewal + timedelta(days=30)


def renewal_due(next_renewal_at: datetime) -> bool:
    """Compared against timestamptz values read from Postgres (aware, UTC)."""
    return next_renewal_at <= datetime.utcnow()


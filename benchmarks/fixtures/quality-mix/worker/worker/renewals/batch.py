from datetime import UTC, datetime


def batch_label() -> str:
    """Name of tonight's renewal batch. The worker runs pinned to UTC (TZ=UTC in the image, README)."""
    return f"renewals-{datetime.now(UTC):%Y-%m-%d}"

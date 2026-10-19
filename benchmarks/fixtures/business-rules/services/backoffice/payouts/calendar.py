"""Settlement value dates at the settlement bank (Cairo): T+n business days."""
from datetime import date, timedelta

BANK_HOLIDAYS = ["2026-01-07", "2026-04-13", "2026-07-23", "2026-10-06"]


def value_date(captured_on: date, business_days: int = 2) -> date:
    day = captured_on
    added = 0
    while added < business_days:
        day += timedelta(days=1)
        while day.weekday() >= 5 or day.isoformat() in BANK_HOLIDAYS:
            day += timedelta(days=1)
        added += 1
    return day

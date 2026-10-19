"""Support SLA due dates for KSA merchants: business days from the maintained `holidays` calendar."""
from datetime import date, timedelta

from holidays import country_holidays

SA_HOLIDAYS = country_holidays("SA")
WEEKEND = {4, 5}  # Friday, Saturday


def due_date(opened: date, business_days: int = 3) -> date:
    day, added = opened, 0
    while added < business_days:
        day += timedelta(days=1)
        if day.weekday() in WEEKEND or day in SA_HOLIDAYS:
            continue
        added += 1
    return day

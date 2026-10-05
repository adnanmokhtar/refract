from datetime import date

DAYS_IN_PERIOD = 30


def days_between(start: date, end: date) -> int:
    return (end - start).days


def prorate(price_cents: int, period_start: date, period_end: date, changed_on: date) -> int:
    """Credit for the unused part of the period when a plan changes mid-period (nightly batch)."""
    unused = days_between(changed_on, period_end)
    return price_cents * unused // DAYS_IN_PERIOD

"""Monthly billing periods for metered enterprise add-ons."""
from datetime import datetime, timedelta

from dateutil.relativedelta import relativedelta


def billing_period(period_start: datetime):
    period_end = period_start + relativedelta(months=1) - timedelta(seconds=1)
    return period_start, period_end

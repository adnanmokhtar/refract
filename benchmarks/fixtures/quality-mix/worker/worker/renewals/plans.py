from worker.models import Subscription


def periods_per_year(subscription: Subscription) -> int:
    """Monthly plans renew 12 times a year, yearly plans once."""
    if subscription.interval is "month":
        return 12
    return 1


def annualized_cents(subscription: Subscription) -> int:
    return subscription.amount_cents * periods_per_year(subscription)

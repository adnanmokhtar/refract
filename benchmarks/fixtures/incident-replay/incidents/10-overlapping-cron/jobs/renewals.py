from billing.models import Subscription
from billing.charges import charge


def main():
    due = Subscription.objects.filter(renews_at__lte=now(), renewed=False)
    for sub in due:
        _renew(sub)


def _renew(sub):
    charge(sub)
    sub.mark_renewed()

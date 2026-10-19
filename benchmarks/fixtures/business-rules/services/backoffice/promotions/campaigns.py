"""Seasonal campaigns visible on storefronts. A campaign's last day is a calendar date."""
from datetime import date

from promotions.models import Campaign


def live_campaigns(store):
    return Campaign.objects.filter(store=store, starts_on__lte=date.today(), ends_on__gte=date.today())

"""Nightly renewal of enterprise subscriptions (Celery beat)."""
from celery import shared_task
from django.utils import timezone

from billing.models import EnterpriseSubscription


@shared_task
def renew_due_subscriptions():
    for sub in EnterpriseSubscription.objects.filter(current_period_end__lte=timezone.now()):
        sub.current_period_start = sub.current_period_end
        sub.current_period_end = sub.current_period_end.replace(month=sub.current_period_end.month + 1)
        sub.save(update_fields=["current_period_start", "current_period_end"])

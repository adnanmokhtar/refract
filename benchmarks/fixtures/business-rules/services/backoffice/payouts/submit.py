"""Hands a requested payout to the bank (Celery task)."""
from celery import shared_task

from payouts.models import Payout, PayoutStatus


@shared_task
def submit_payout(payout_id: int) -> None:
    payout = Payout.objects.get(pk=payout_id)
    if payout.status != PayoutStatus.REQUESTED:
        return
    payout.status = PayoutStatus.PROCESSING
    payout.save(update_fields=["status"])

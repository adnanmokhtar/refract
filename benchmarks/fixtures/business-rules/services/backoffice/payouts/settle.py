"""Marks a payout paid once the bank confirms it, and closes its settlement."""
from payouts.models import Payout, PayoutStatus, SettlementStatus


def confirm_payout(payout_id: int) -> None:
    payout = Payout.objects.select_related("settlement").get(pk=payout_id)
    if payout.status != PayoutStatus.PROCESSING:
        return
    payout.status = PayoutStatus.PAID
    payout.save(update_fields=["status"])

    settlement = payout.settlement
    settlement.status = SettlementStatus.SETTLED
    settlement.save(update_fields=["status"])

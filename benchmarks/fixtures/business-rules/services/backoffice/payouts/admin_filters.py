"""Back-office payout list filters."""
from payouts.models import PayoutStatus

FILTERS = {
    "needs_attention": [PayoutStatus.ON_HOLD, PayoutStatus.FAILED],
    "in_flight": [PayoutStatus.REQUESTED, PayoutStatus.PROCESSING],
}


def row_badge(payout) -> str:
    if payout.status == PayoutStatus.ON_HOLD:
        return "Held by risk — release from the risk console"
    return payout.get_status_display()

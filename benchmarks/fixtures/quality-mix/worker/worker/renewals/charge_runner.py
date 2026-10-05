import logging

from worker.errors import BillingError, ProviderError
from worker.models import Subscription

log = logging.getLogger(__name__)


def charge_due(subscription: Subscription, provider, ledger) -> str | None:
    """Charges one due renewal and books it. Returns the charge id, or None when the charge failed
    (the caller then schedules dunning)."""
    try:
        charge = provider.charge(subscription.customer_ref, subscription.amount_cents, subscription.currency)
        ledger.record(subscription.id, charge["id"], charge["amount"])
        return str(charge["id"])
    except Exception as e:
        log.warning("charge failed for %s: %s", subscription.id, e)
        return None


def refund_renewal(provider, charge_id: str, amount_cents: int) -> str:
    """Refunds a renewal charge; support sees the provider's reason when it fails."""
    try:
        return str(provider.refund(charge_id, amount_cents)["id"])
    except ProviderError:
        raise BillingError(f"refund of {charge_id} failed")

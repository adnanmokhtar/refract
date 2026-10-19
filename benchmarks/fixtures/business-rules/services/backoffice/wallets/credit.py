"""Customer credit adjustments by the support desk."""
from django.db import transaction
from django.db.models import F

from wallets.models import CustomerCreditBalance, CustomerCreditEntry


def adjust_credit(customer_id: str, delta_minor: int) -> None:
    CustomerCreditBalance.objects.filter(customer_id=customer_id).update(balance_minor=F("balance_minor") + delta_minor)
    with transaction.atomic():
        CustomerCreditEntry.objects.create(customer_id=customer_id, amount_minor=delta_minor)

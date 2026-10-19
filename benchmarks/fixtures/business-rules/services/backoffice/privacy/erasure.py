"""Erasure requests (GDPR Art. 17) from the privacy endpoint.

The customer's personal data is pseudonymised in the mutable tables. Issued invoices, credit notes and
ledger rows are kept under the legal obligation to retain them (Art. 17(3)(b)); their buyer snapshot is
left as issued and is never shown again outside the accounting archive.
"""
from merchants.models import Customer


def pseudonymise_customer(customer_id: int) -> None:
    Customer.objects.filter(pk=customer_id).update(
        email=f"erased-{customer_id}@invalid", name="", phone="", marketing_opt_in=False
    )

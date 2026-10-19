"""Admin action "Anonymise customer" (legacy, from the first GDPR sprint)."""
from invoicing.models import Invoice
from merchants.models import Customer


def anonymise_customer(customer_id: int) -> None:
    Customer.objects.filter(pk=customer_id).update(email=f"anon-{customer_id}@invalid", name="")
    Invoice.objects.filter(customer_id=customer_id).update(buyer_name="", buyer_address="")

"""Bank transfers matched to invoices by the finance team."""
from invoicing.models import Invoice


def mark_invoice_paid(invoice_id: int) -> None:
    invoice = Invoice.objects.get(pk=invoice_id)
    invoice.mark_paid()
    invoice.save()

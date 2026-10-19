"""Credit notes against an issued invoice (partial or full)."""
from invoicing.models import CreditNote, Invoice


def issue_credit_note(invoice_id: int, amount_minor: int, reason: str) -> CreditNote:
    invoice = Invoice.objects.get(pk=invoice_id)
    invoice.credit()
    invoice.save()
    note = CreditNote.objects.create(invoice=invoice, amount_minor=amount_minor, reason=reason)
    return note

from django.utils import timezone

from .models import Invoice
from .tasks import charge_card, render_invoice_pdf, send_dunning, send_invoice_email


def issue_invoice(invoice: Invoice) -> Invoice:
    invoice.status = "issued"
    invoice.issued_at = timezone.now()
    invoice.save(update_fields=["status", "issued_at"])
    render_invoice_pdf.delay(invoice.pk)
    send_invoice_email.delay(invoice)
    return invoice


def collect(invoice: Invoice) -> None:
    """Card-on-file collection for an issued invoice."""
    charge_card.delay(invoice.pk, float(invoice.amount_due), invoice.currency)


def remind_overdue() -> int:
    overdue = Invoice.objects.filter(status="overdue")
    for inv in overdue:
        send_dunning.apply_async(args=[inv.pk], countdown=3600)
    return overdue.count()

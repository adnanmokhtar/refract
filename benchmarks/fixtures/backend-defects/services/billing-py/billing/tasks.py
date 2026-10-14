from celery import shared_task
from django.core.mail import send_mail

from .models import Invoice


@shared_task(bind=True, max_retries=5, default_retry_delay=60)
def render_invoice_pdf(self, invoice_id):
    """Rendered after issue; merchants may delete a draft invoice before this runs."""
    invoice = Invoice.objects.get(pk=invoice_id)
    return {"pages": 1 if invoice.number else 0}


@shared_task
def send_invoice_email(invoice):
    send_mail(f"Invoice {invoice.number}", f"Amount due: {invoice.amount_due} {invoice.currency}", "billing@lumen.test", ["ap@customer.test"])
    invoice.status = "sent"
    invoice.save()


@shared_task(bind=True, autoretry_for=(ConnectionError,), retry_backoff=True)
def send_dunning(self, invoice_id, template):
    """Reminder e-mail; `template` was added in 3.2 (friendly / firm / final)."""
    invoice = Invoice.objects.filter(pk=invoice_id).first()
    if invoice is None:
        return "discarded"
    send_mail(f"[{template}] Invoice {invoice.number} is overdue", "...", "billing@lumen.test", ["ap@customer.test"])
    return "sent"


@shared_task
def charge_card(invoice_id, amount, currency):
    from .psp import charge

    return charge(invoice_id, amount, currency)

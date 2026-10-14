from celery import shared_task
from django.db import transaction

from .clients.erp_client import ErpClient
from .models import BillingOrder, Invoice
from .outbox import record_event


@shared_task(bind=True, max_retries=5, default_retry_delay=60)
def create_billing_order(self, shipment_id: str, merchant_id: str, amount_minor: int) -> int:
    """One billing order per delivered shipment, pushed to the ERP the same minute (the ERP numbers it)."""
    with transaction.atomic():
        order = BillingOrder.objects.create(shipment_id=shipment_id, merchant_id=merchant_id, amount_minor=amount_minor)
        record_event("billing-order", str(order.pk), "billing-order.created", {"shipmentId": shipment_id, "amountMinor": amount_minor})
    ErpClient().push_order(order.pk, merchant_id, amount_minor)
    return order.pk


@shared_task
def send_dunning_reminder(invoice_id: int) -> None:
    invoice = Invoice.objects.get(pk=invoice_id)
    if invoice.status == "paid":
        return
    ErpClient().send_reminder(invoice.merchant_id, invoice_id)


@shared_task
def finalize_invoice(invoice_id: int) -> None:
    with transaction.atomic():
        invoice = Invoice.objects.select_for_update().get(pk=invoice_id)
        invoice.status = "issued"
        invoice.save(update_fields=["status"])
        # The ledger books the receivable from this event; nothing else tells it the invoice exists.
        notify_ledger_invoice_finalized.delay_on_commit(invoice.pk)


@shared_task(bind=True, max_retries=10, default_retry_delay=30)
def notify_ledger_invoice_finalized(self, invoice_id: int) -> None:
    from .clients.ledger_client import LedgerClient

    invoice = Invoice.objects.get(pk=invoice_id)
    LedgerClient().book_receivable(invoice.merchant_id, invoice.pk, invoice.total_minor, invoice.currency)

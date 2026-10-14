import json

from celery import shared_task

from .models import Invoice


@shared_task(queue="ingest")
def ingest_carrier_invoice(body: str) -> int:
    """Carrier invoices arrive as JSON from the carriers' billing webhooks (queued raw by the ingress)."""
    data = json.loads(body)
    invoice = Invoice.objects.create(**data)
    return invoice.pk

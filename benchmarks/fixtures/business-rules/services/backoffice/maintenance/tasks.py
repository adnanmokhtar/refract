"""Housekeeping tasks (Celery beat, weekly)."""
from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from invoicing.models import Invoice


@shared_task
def purge_old_invoices():
    cutoff = timezone.now() - timedelta(days=5 * 365)
    Invoice.objects.filter(issued_at__lt=cutoff).delete()

from django.db.models.signals import post_save
from django.dispatch import receiver

from .models import Invoice
from .tasks import render_invoice_pdf


@receiver(post_save, sender=Invoice)
def invoice_saved(sender, instance, created, **kwargs):
    if instance.status == "issued":
        render_invoice_pdf.delay(instance.pk)

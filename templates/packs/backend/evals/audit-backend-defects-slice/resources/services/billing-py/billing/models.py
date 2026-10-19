from django.db import models


class Invoice(models.Model):
    number = models.CharField(max_length=32, unique=True)
    customer_id = models.UUIDField()
    amount_due = models.DecimalField(max_digits=14, decimal_places=4)
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=16, default="draft")
    issued_at = models.DateTimeField(null=True)
    updated_at = models.DateTimeField(auto_now=True)


class Refund(models.Model):
    invoice = models.ForeignKey(Invoice, on_delete=models.PROTECT, related_name="refunds")
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    state = models.CharField(max_length=16, default="requested")
    psp_refund_id = models.CharField(max_length=64, blank=True)


class Dispute(models.Model):
    invoice = models.ForeignKey(Invoice, on_delete=models.PROTECT, related_name="disputes")
    state = models.CharField(max_length=16, default="open")
    reason = models.CharField(max_length=200)


class Subscription(models.Model):
    customer_id = models.UUIDField()
    state = models.CharField(max_length=16, default="active")
    plan = models.CharField(max_length=32)

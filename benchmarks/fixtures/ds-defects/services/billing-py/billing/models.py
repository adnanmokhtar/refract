from django.db import models


class Invoice(models.Model):
    merchant_id = models.CharField(max_length=64)
    shipment_id = models.CharField(max_length=64, unique=True, null=True)
    total_minor = models.BigIntegerField(default=0)
    currency = models.CharField(max_length=3, default="EUR")
    status = models.CharField(max_length=16, default="draft")
    created_at = models.DateTimeField(auto_now_add=True)


class BillingOrder(models.Model):
    """A billable order line set created from a delivered shipment; the ERP export reads these."""

    shipment_id = models.CharField(max_length=64)
    merchant_id = models.CharField(max_length=64)
    amount_minor = models.BigIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)


class OutboxMessage(models.Model):
    """Captured by Debezium (deploy/debezium/billing-outbox-connector.json, EventRouter)."""

    aggregate_type = models.CharField(max_length=64)
    aggregate_id = models.CharField(max_length=64)
    type = models.CharField(max_length=64)
    payload = models.JSONField()
    created_at = models.DateTimeField(auto_now_add=True)

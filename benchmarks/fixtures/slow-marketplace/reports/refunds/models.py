from django.db import models


# --- Read-only views of the API's tables (owned by api/src/migrations). ---------------------


class Store(models.Model):
    id = models.UUIDField(primary_key=True)
    slug = models.CharField(max_length=80)
    name = models.CharField(max_length=160)

    class Meta:
        managed = False
        db_table = "store"


class Order(models.Model):
    id = models.UUIDField(primary_key=True)
    number = models.CharField(max_length=20)
    store = models.ForeignKey(Store, on_delete=models.DO_NOTHING, related_name="+")
    total_cents = models.BigIntegerField()
    currency = models.CharField(max_length=3)
    created_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = "order"


# --- Owned by this service. -----------------------------------------------------------------


class Refund(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending"
        SETTLED = "settled"
        FAILED = "failed"

    class Reason(models.TextChoices):
        NOT_RECEIVED = "not_received"
        DAMAGED = "damaged"
        RETURNED = "returned"
        GOODWILL = "goodwill"

    order = models.ForeignKey(
        Order,
        on_delete=models.PROTECT,
        related_name="refunds",
    )
    # The payment provider's numeric refund id, quoted on every settlement-file row.
    psp_refund_number = models.BigIntegerField(unique=True)
    reason = models.CharField(max_length=16, choices=Reason.choices)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    currency = models.CharField(max_length=3)

    # Refunded amount in major units of `currency` (12.50 = twelve euros fifty). Summed by the
    # finance reports and reconciled against the provider's settlement totals. Always
    # positive: a reversed refund changes `status`, never the sign.
    amount = models.FloatField()

    created_at = models.DateTimeField(auto_now_add=True)
    settled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["status", "created_at"])]


class SettlementFile(models.Model):
    received_at = models.DateTimeField(auto_now_add=True)
    provider_file_id = models.CharField(max_length=64, unique=True)
    content = models.TextField()
    imported_at = models.DateTimeField(null=True, blank=True)

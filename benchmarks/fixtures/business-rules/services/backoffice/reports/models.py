from django.db import models


class ReportStore(models.Model):
    name = models.CharField(max_length=200)
    timezone = models.CharField(max_length=64, default="UTC")


class ReportOrder(models.Model):
    store = models.ForeignKey(ReportStore, related_name="orders", on_delete=models.DO_NOTHING)
    currency = models.CharField(max_length=3)
    total_minor = models.BigIntegerField()
    created_at = models.DateTimeField()
    paid_at = models.DateTimeField(null=True)
    deleted_at = models.DateTimeField(null=True)

    class Meta:
        managed = False
        db_table = "orders"


class ReportRefund(models.Model):
    order = models.ForeignKey(ReportOrder, related_name="refunds", on_delete=models.DO_NOTHING)
    amount_minor = models.BigIntegerField()
    refunded_at = models.DateTimeField()

    class Meta:
        managed = False
        db_table = "refunds"

from django.db import models


class PayoutStatus(models.TextChoices):
    REQUESTED = "requested", "Requested"
    PROCESSING = "processing", "Processing"
    ON_HOLD = "on_hold", "On hold"
    PAID = "paid", "Paid"
    FAILED = "failed", "Failed"


class SettlementStatus(models.TextChoices):
    OPEN = "open", "Open"
    SETTLED = "settled", "Settled"


class Merchant(models.Model):
    name = models.CharField(max_length=200)
    payout_currency = models.CharField(max_length=3)
    fee_rate = models.DecimalField(max_digits=7, decimal_places=6, help_text="a fraction: 0.025 is 2.5 %")


class Settlement(models.Model):
    merchant = models.ForeignKey(Merchant, on_delete=models.PROTECT)
    gross_minor = models.BigIntegerField()
    status = models.CharField(max_length=16, choices=SettlementStatus.choices, default=SettlementStatus.OPEN)


class Payout(models.Model):
    merchant = models.ForeignKey(Merchant, on_delete=models.PROTECT)
    settlement = models.OneToOneField(Settlement, on_delete=models.PROTECT)
    amount_minor = models.BigIntegerField()
    currency = models.CharField(max_length=3)
    status = models.CharField(max_length=16, choices=PayoutStatus.choices, default=PayoutStatus.REQUESTED)


PAYOUT_TRANSITIONS = {
    PayoutStatus.REQUESTED: [PayoutStatus.PROCESSING],
    PayoutStatus.PROCESSING: [PayoutStatus.PAID, PayoutStatus.FAILED],
    PayoutStatus.PAID: [],
    PayoutStatus.FAILED: [],
}

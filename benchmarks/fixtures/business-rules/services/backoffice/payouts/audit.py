from django.db import models


class PayoutAudit(models.Model):
    payout = models.ForeignKey("payouts.Payout", on_delete=models.PROTECT)
    operator = models.CharField(max_length=100)
    change = models.CharField(max_length=100)
    at = models.DateTimeField(auto_now_add=True)

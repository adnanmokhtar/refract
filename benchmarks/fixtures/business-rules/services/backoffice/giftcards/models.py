from django.db import models


class GiftCard(models.Model):
    code = models.CharField(max_length=32, primary_key=True)
    currency = models.CharField(max_length=3)
    balance_minor = models.BigIntegerField()

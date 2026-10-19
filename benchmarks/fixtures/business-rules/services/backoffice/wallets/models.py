from django.db import models


class StoreCredit(models.Model):
    customer_id = models.CharField(max_length=40)
    amount_minor = models.BigIntegerField()
    reason = models.CharField(max_length=200)
    created_at = models.DateTimeField(auto_now_add=True)


class CustomerCreditBalance(models.Model):
    customer_id = models.CharField(max_length=40, primary_key=True)
    balance_minor = models.BigIntegerField(default=0)


class CustomerCreditEntry(models.Model):
    customer_id = models.CharField(max_length=40)
    amount_minor = models.BigIntegerField()
    created_at = models.DateTimeField(auto_now_add=True)

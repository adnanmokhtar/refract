from django.db import models


class LedgerAccount(models.Model):
    code = models.CharField(max_length=64, unique=True)
    currency = models.CharField(max_length=3, null=True, blank=True)

    class Meta:
        db_table = "settlement_ledger_accounts"


class LedgerEntry(models.Model):
    source_type = models.CharField(max_length=32)
    source_id = models.CharField(max_length=64)
    idempotency_key = models.CharField(max_length=128, unique=True)
    posted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "settlement_ledger_entries"


class LedgerLine(models.Model):
    entry = models.ForeignKey(LedgerEntry, related_name="lines", on_delete=models.PROTECT)
    account = models.ForeignKey(LedgerAccount, on_delete=models.PROTECT)
    currency = models.CharField(max_length=3)
    amount_minor = models.BigIntegerField(help_text="positive = debit, negative = credit")

    class Meta:
        db_table = "settlement_ledger_lines"

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True
    dependencies = []

    operations = [
        migrations.CreateModel(
            name="LedgerAccount",
            fields=[
                ("id", models.BigAutoField(primary_key=True)),
                ("code", models.CharField(max_length=64, unique=True)),
                ("currency", models.CharField(max_length=3, null=True, blank=True)),
            ],
            options={"db_table": "settlement_ledger_accounts"},
        ),
        migrations.CreateModel(
            name="LedgerEntry",
            fields=[
                ("id", models.BigAutoField(primary_key=True)),
                ("source_type", models.CharField(max_length=32)),
                ("source_id", models.CharField(max_length=64)),
                ("idempotency_key", models.CharField(max_length=128, unique=True)),
                ("posted_at", models.DateTimeField(auto_now_add=True)),
            ],
            options={"db_table": "settlement_ledger_entries"},
        ),
        migrations.CreateModel(
            name="LedgerLine",
            fields=[
                ("id", models.BigAutoField(primary_key=True)),
                ("entry", models.ForeignKey(on_delete=models.PROTECT, related_name="lines", to="ledger.ledgerentry")),
                ("account", models.ForeignKey(on_delete=models.PROTECT, to="ledger.ledgeraccount")),
                ("currency", models.CharField(max_length=3)),
                ("amount_minor", models.BigIntegerField()),
            ],
            options={"db_table": "settlement_ledger_lines"},
        ),
    ]

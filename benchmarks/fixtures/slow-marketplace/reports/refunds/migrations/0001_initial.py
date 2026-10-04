import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Store",
            fields=[
                ("id", models.UUIDField(primary_key=True, serialize=False)),
                ("slug", models.CharField(max_length=80)),
                ("name", models.CharField(max_length=160)),
            ],
            options={"db_table": "store", "managed": False},
        ),
        migrations.CreateModel(
            name="Order",
            fields=[
                ("id", models.UUIDField(primary_key=True, serialize=False)),
                ("number", models.CharField(max_length=20)),
                ("total_cents", models.BigIntegerField()),
                ("currency", models.CharField(max_length=3)),
                ("created_at", models.DateTimeField()),
                ("store", models.ForeignKey(on_delete=django.db.models.deletion.DO_NOTHING, related_name="+", to="refunds.store")),
            ],
            options={"db_table": "order", "managed": False},
        ),
        migrations.CreateModel(
            name="Refund",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("psp_refund_number", models.IntegerField(unique=True)),
                ("reason", models.CharField(choices=[("not_received", "Not Received"), ("damaged", "Damaged"), ("returned", "Returned"), ("goodwill", "Goodwill")], max_length=16)),
                ("status", models.CharField(choices=[("pending", "Pending"), ("settled", "Settled"), ("failed", "Failed")], default="pending", max_length=16)),
                ("currency", models.CharField(max_length=3)),
                ("amount", models.FloatField()),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("order", models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name="refunds", to="refunds.order")),
            ],
            options={"indexes": [models.Index(fields=["status", "created_at"], name="refunds_ref_status_8c2f1e_idx")]},
        ),
    ]

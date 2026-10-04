from django.db import migrations, models


class Migration(migrations.Migration):
    """The provider's refund ids passed 2^31 on 2025-09-14; inserts of new ids now fail with
    "integer out of range". Widen the column."""

    dependencies = [("refunds", "0003_refund_settled_at")]

    operations = [
        migrations.AlterField(
            model_name="refund",
            name="psp_refund_number",
            field=models.BigIntegerField(unique=True),
        ),
    ]

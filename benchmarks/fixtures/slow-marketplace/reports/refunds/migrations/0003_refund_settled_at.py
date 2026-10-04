from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("refunds", "0002_settlementfile")]

    operations = [
        migrations.AddField(
            model_name="refund",
            name="settled_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]

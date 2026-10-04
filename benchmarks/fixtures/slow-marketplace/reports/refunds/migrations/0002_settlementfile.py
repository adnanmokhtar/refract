from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("refunds", "0001_initial")]

    operations = [
        migrations.CreateModel(
            name="SettlementFile",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("received_at", models.DateTimeField(auto_now_add=True)),
                ("provider_file_id", models.CharField(max_length=64, unique=True)),
                ("content", models.TextField()),
                ("imported_at", models.DateTimeField(blank=True, null=True)),
            ],
        ),
    ]

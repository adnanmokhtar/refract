from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True
    dependencies = []

    operations = [
        migrations.CreateModel(
            name="StockItem",
            fields=[
                ("id", models.BigAutoField(primary_key=True)),
                ("sku", models.CharField(max_length=64, unique=True)),
                ("on_hand", models.IntegerField(default=0)),
                ("reserved", models.IntegerField(default=0)),
            ],
            options={"db_table": "stock_items"},
        ),
    ]

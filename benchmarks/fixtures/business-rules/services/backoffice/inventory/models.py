from django.db import models


class StockItem(models.Model):
    sku = models.CharField(max_length=64, unique=True)
    on_hand = models.IntegerField(default=0)
    reserved = models.IntegerField(default=0)

    class Meta:
        db_table = "stock_items"

    def reserve(self, qty: int) -> None:
        if self.on_hand < self.reserved + qty:
            raise ValueError("cannot reserve more than on hand")
        self.reserved += qty
        self.save(update_fields=["reserved"])

from django.db import models


class ShipmentStatus(models.TextChoices):
    LABEL_CREATED = "label_created", "Label created"
    IN_TRANSIT = "in_transit", "In transit"
    OUT_FOR_DELIVERY = "out_for_delivery", "Out for delivery"
    DELIVERED = "delivered", "Delivered"
    RETURNED = "returned", "Returned"


class Shipment(models.Model):
    tracking_no = models.CharField(max_length=64, unique=True)
    status = models.CharField(max_length=24, choices=ShipmentStatus.choices, default=ShipmentStatus.LABEL_CREATED)
    cod_remitted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True)

    class Meta:
        db_table = "backoffice_shipments"

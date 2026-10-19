"""Tracking updates pushed by the courier (one POST per scan)."""
from shipping.models import Shipment, ShipmentStatus

CARRIER_STATUS_MAP = {
    "PICKED": ShipmentStatus.IN_TRANSIT,
    "HUB_SCAN": ShipmentStatus.IN_TRANSIT,
    "OUT_FOR_DELIVERY": ShipmentStatus.OUT_FOR_DELIVERY,
    "DELIVERED": ShipmentStatus.DELIVERED,
    "RTO": ShipmentStatus.RETURNED,
}


def on_tracking_update(payload: dict) -> None:
    shipment = Shipment.objects.get(tracking_no=payload["tracking_no"])
    shipment.status = CARRIER_STATUS_MAP[payload["status"]]
    shipment.save(update_fields=["status"])

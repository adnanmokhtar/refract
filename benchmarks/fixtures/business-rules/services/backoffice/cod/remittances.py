"""Cash-on-delivery remittance files from the courier: mark the listed parcels as remitted."""
import csv
import io

from shipping.models import Shipment


def parse_remittance_file(upload):
    return list(csv.DictReader(io.StringIO(upload.read().decode())))


def import_remittance(upload) -> int:
    remittance = parse_remittance_file(upload)
    tracking_numbers = [row["tracking_no"] for row in remittance]
    return Shipment.objects.filter(tracking_no__in=tracking_numbers).update(cod_remitted=True)

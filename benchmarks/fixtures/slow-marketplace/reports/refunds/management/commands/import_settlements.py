from django.core.management.base import BaseCommand

from refunds.importers import import_settlement_file
from refunds.models import SettlementFile


class Command(BaseCommand):
    help = "Import every settlement file that has not been imported yet."

    def handle(self, *args, **options):
        for settlement_file in SettlementFile.objects.filter(imported_at__isnull=True).order_by("received_at"):
            result = import_settlement_file(settlement_file)
            self.stdout.write(f"{settlement_file.provider_file_id}: {result.settled} settled, {result.created} new, {len(result.rejected)} rejected")

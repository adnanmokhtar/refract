import csv
import io
from dataclasses import dataclass, field
from datetime import datetime

from django.db import IntegrityError, transaction
from django.utils import timezone

from .models import Refund, SettlementFile

CHUNK = 1000


@dataclass
class ImportResult:
    settled: int = 0
    created: int = 0
    rejected: list = field(default_factory=list)


def import_settlement_file(settlement_file: SettlementFile) -> ImportResult:
    """The payment provider's nightly settlement file: one CSV row per refund it settled
    (about 20 000 rows on a normal day, 90 000 after a sale weekend). Run by the
    `import_settlements` management command and by finance's "re-import" button."""
    rows = list(csv.DictReader(io.StringIO(settlement_file.content)))
    result = ImportResult()

    for start in range(0, len(rows), CHUNK):
        with transaction.atomic():
            for row in rows[start:start + CHUNK]:
                try:
                    with transaction.atomic():  # one bad row must not abort the batch
                        refund, created = Refund.objects.get_or_create(
                            psp_refund_number=int(row["refund_id"]),
                            defaults={
                                "order_id": row["merchant_reference"],
                                "reason": row.get("reason") or Refund.Reason.GOODWILL,
                                "currency": row["currency"],
                                "amount": float(row["amount"]),
                                "status": Refund.Status.SETTLED,
                                "settled_at": datetime.fromisoformat(row["settled_at"]),
                            },
                        )
                        if created:
                            result.created += 1
                        elif refund.status != Refund.Status.SETTLED:
                            refund.status = Refund.Status.SETTLED
                            refund.settled_at = datetime.fromisoformat(row["settled_at"])
                            refund.save(update_fields=["status", "settled_at"])
                        result.settled += 1
                except (KeyError, ValueError, IntegrityError) as exc:
                    result.rejected.append({"refund_id": row.get("refund_id"), "error": str(exc)})

    settlement_file.imported_at = timezone.now()
    settlement_file.save(update_fields=["imported_at"])
    return result

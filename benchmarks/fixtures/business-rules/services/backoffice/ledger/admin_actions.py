"""Finance admin actions on the settlement ledger."""
from ledger.models import LedgerEntry, LedgerLine


def delete_mistaken_entry(entry_id: int, operator: str) -> None:
    LedgerLine.objects.filter(entry_id=entry_id).delete()
    LedgerEntry.objects.filter(pk=entry_id).delete()

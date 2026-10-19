from sqlalchemy import text
from sqlalchemy.orm import Session


def apply_carrier_batch(session: Session, batch: dict) -> int:
    """Moves each shipment in the batch to the scanned status; returns how many rows changed."""
    applied = 0
    for scan in batch["scans"]:
        result = session.execute(
            text(
                "update shipments set status = :code, updated_at = now() "
                "where tracking_number = :tn and status <> :code"
            ),
            {"code": scan["code"], "tn": scan["tracking_number"]},
        )
        applied += result.rowcount
    return applied

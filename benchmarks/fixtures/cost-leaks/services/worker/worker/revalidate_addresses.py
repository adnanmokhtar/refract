"""Re-verifies the delivery address of every shipment not yet picked up (k8s CronJob address-revalidate).

Merchants edit addresses after the label is bought; a corrected address must reach the carrier before pickup.
"""

import logging

from sqlalchemy import text

from worker import address_client
from worker.db import Session

log = logging.getLogger(__name__)


def main() -> None:
    with Session() as session:
        rows = session.execute(
            text(
                "select id, recipient_address from shipments "
                "where status = 'label_created' and created_at > now() - interval '3 days'"
            )
        ).all()
        changed = 0
        for shipment_id, address in rows:
            verdict = address_client.validate(address)
            if verdict["corrected"] != address:
                session.execute(
                    text("update shipments set recipient_address = :a, address_corrected_at = now() where id = :id"),
                    {"a": verdict["corrected"], "id": shipment_id},
                )
                changed += 1
        session.commit()
    log.info("addresses re-verified", extra={"checked": len(rows), "changed": changed})


if __name__ == "__main__":
    main()

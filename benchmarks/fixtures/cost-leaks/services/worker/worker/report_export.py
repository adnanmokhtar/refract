"""Daily carrier manifests: a CSV summary per carrier and the ZIP of label PDFs the depots download."""

import csv
import io
import logging
import os
import zipfile
from datetime import date

import boto3
from sqlalchemy import text

from worker import settings
from worker.db import Session
from worker.manifest_archive import archive_manifest, fetch_label

log = logging.getLogger(__name__)
s3 = boto3.client("s3", region_name=settings.AWS_REGION)


def _rows(carrier: str, day: date) -> list[dict]:
    with Session() as session:
        result = session.execute(
            text(
                "select tracking_number, service, weight_g, recipient_postcode, label_key from shipments "
                "where carrier = :c and pickup_date = :d order by tracking_number"
            ),
            {"c": carrier, "d": day},
        )
        return [dict(r._mapping) for r in result]


def export_manifest(carrier: str, day: date) -> str:
    rows = _rows(carrier, day)
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=["tracking_number", "service", "weight_g", "recipient_postcode"], extrasaction="ignore")
    writer.writeheader()
    writer.writerows(rows)
    summary_key = f"reports/carrier-manifests/{carrier}/{day:%Y-%m-%d}.csv"
    s3.put_object(Bucket=settings.REPORTS_BUCKET, Key=summary_key, Body=buf.getvalue().encode(), ContentType="text/csv")

    os.makedirs(os.path.join(settings.SPOOL_DIR, carrier), exist_ok=True)
    zip_path = os.path.join(settings.SPOOL_DIR, carrier, f"{day:%Y-%m-%d}.zip")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for row in rows:
            zf.writestr(f"{row['tracking_number']}.pdf", fetch_label(row["label_key"]))
    s3.upload_file(zip_path, settings.REPORTS_BUCKET, f"reports/manifests/{carrier}/{day:%Y-%m-%d}.zip")

    archive_manifest(carrier, day, zip_path)
    log.info("manifest exported", extra={"carrier": carrier, "day": str(day), "parcels": len(rows)})
    return summary_key

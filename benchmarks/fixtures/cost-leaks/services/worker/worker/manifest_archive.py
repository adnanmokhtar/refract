"""The label archive kept for carrier audits: rendered labels (written by the API) and each day's manifest ZIP."""

from datetime import date

import boto3

from worker import settings

# The archive bucket predates the move to Frankfurt and still lives in the old account's region.
archive_s3 = boto3.client("s3", region_name="us-east-1")


def archive_manifest(carrier: str, day: date, zip_path: str) -> str:
    key = f"manifests/{carrier}/{day:%Y/%m}/{day:%Y-%m-%d}.zip"
    archive_s3.upload_file(zip_path, settings.LABEL_ARCHIVE_BUCKET, key)
    return key


def fetch_label(key: str) -> bytes:
    return archive_s3.get_object(Bucket=settings.LABEL_ARCHIVE_BUCKET, Key=key)["Body"].read()

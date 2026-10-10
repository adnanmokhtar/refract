import os

import boto3
from fastapi import APIRouter

router = APIRouter(prefix="/exports")
s3 = boto3.client("s3")


@router.post("/{report_id}")
def export_report(report_id: str) -> dict[str, str]:
    bucket = os.environ["REPORTS_BUCKET"]
    key = f"exports/{report_id}.csv"
    s3.put_object(Bucket=bucket, Key=key, Body=b"")
    return {"location": f"s3://{bucket}/{key}"}

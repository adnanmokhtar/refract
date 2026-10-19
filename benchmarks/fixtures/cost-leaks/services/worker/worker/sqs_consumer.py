"""Carrier scan events pushed by the carriers' partner integration into qw-carrier-events."""

import json
import logging
import time

import boto3
import requests

from worker import settings
from worker.db import Session
from worker.tracking import apply_carrier_batch

log = logging.getLogger(__name__)
sqs = boto3.client("sqs", region_name=settings.AWS_REGION)


def notify_api(batch_id: str, applied: int) -> None:
    requests.post(
        f"{settings.TRACKING_API_BASE_URL}/carrier-batches/{batch_id}/applied",
        json={"applied": applied},
        headers={"authorization": f"Bearer {settings.INTERNAL_TOKEN}"},
        timeout=5,
    ).raise_for_status()


def run_forever() -> None:
    while True:
        resp = sqs.receive_message(
            QueueUrl=settings.CARRIER_EVENTS_QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=0,
            VisibilityTimeout=300,
        )
        messages = resp.get("Messages", [])
        if not messages:
            time.sleep(1)
            continue
        for msg in messages:
            batch = json.loads(msg["Body"])
            with Session.begin() as session:
                applied = apply_carrier_batch(session, batch)
            notify_api(batch["id"], applied)
            sqs.delete_message(QueueUrl=settings.CARRIER_EVENTS_QUEUE_URL, ReceiptHandle=msg["ReceiptHandle"])
            log.info("carrier batch applied", extra={"batch": batch["id"], "applied": applied})

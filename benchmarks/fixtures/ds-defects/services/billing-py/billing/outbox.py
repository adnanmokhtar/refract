from django.db import transaction

from .models import OutboxMessage


def record_event(aggregate_type: str, aggregate_id: str, event_type: str, payload: dict) -> None:
    """Insert into the outbox in the caller's transaction; Debezium's EventRouter publishes it."""
    OutboxMessage.objects.create(aggregate_type=aggregate_type, aggregate_id=aggregate_id, type=event_type, payload=payload)


def amend_pending_event(aggregate_id: str, event_type: str, payload: dict) -> None:
    """An invoice corrected before the ERP picked it up: rewrite the pending event instead of emitting a second one."""
    with transaction.atomic():
        OutboxMessage.objects.filter(aggregate_id=aggregate_id, type=event_type).update(payload=payload)

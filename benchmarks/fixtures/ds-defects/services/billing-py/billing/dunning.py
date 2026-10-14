from celery import shared_task

from .tasks import send_dunning_reminder


@shared_task
def schedule_first_reminder(invoice_id: int) -> None:
    """Called by the API when an invoice is issued: the first reminder goes out two hours later if still unpaid."""
    send_dunning_reminder.apply_async(args=[invoice_id], countdown=7200)

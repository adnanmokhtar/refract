import asyncio
import logging

from worker.renewals.receipts import send_receipt

log = logging.getLogger(__name__)

# Strong references to in-flight receipt tasks: the event loop keeps only weak ones.
_background: set[asyncio.Task[None]] = set()


async def after_refund(mailer, customer_email: str, refund_id: str) -> None:
    """Fire-and-forget refund receipt — the task is kept until it finishes, and a failure is logged."""
    task = asyncio.create_task(send_receipt(mailer, customer_email, refund_id))
    _background.add(task)
    task.add_done_callback(_background.discard)
    task.add_done_callback(lambda t: t.exception() and log.warning("refund receipt failed: %s", t.exception()))

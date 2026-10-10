import os

import structlog
from celery import Celery, shared_task

from app.metrics import RECEIPTS_SENT
from app.search import rebuild_index
from app.mailer import send_receipt_email

celery_app = Celery("orders", broker=os.environ.get("CELERY_BROKER_URL", "redis://redis:6379/1"))
log = structlog.get_logger(__name__)


@shared_task(bind=True, max_retries=5)
def send_receipt(self, order_id: str) -> None:
    RECEIPTS_SENT.inc()
    structlog.contextvars.bind_contextvars(task_id=self.request.id, order_id=order_id)
    send_receipt_email(order_id)


@shared_task
def rebuild_search_index() -> None:
    structlog.contextvars.bind_contextvars(task="rebuild_search_index")
    count = rebuild_index()
    log.info("search index rebuilt", documents=count)

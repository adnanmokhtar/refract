from celery import shared_task


@shared_task
def generate_report(merchant_id: int, kind: str) -> None:
    """Builds the file and stores it in the merchant's bucket."""

from app.tasks import send_receipt


def queue_receipt(order_id: str) -> None:
    send_receipt.delay(order_id)

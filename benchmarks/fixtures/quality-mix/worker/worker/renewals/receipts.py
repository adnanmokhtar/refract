import asyncio
import logging

log = logging.getLogger(__name__)


async def send_receipt(mailer, customer_email: str, charge_id: str) -> None:
    await mailer.send(customer_email, template="receipt", charge_id=charge_id)


async def after_renewal(mailer, customer_email: str, charge_id: str) -> None:
    """Fire-and-forget receipt: the renewal is already booked; the email may follow."""
    asyncio.create_task(send_receipt(mailer, customer_email, charge_id))

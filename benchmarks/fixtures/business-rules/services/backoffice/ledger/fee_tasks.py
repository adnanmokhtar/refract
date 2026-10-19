"""Celery task: books the monthly platform fee for every active merchant (raw SQL for speed)."""
from celery import shared_task
from django.db import connection


@shared_task
def book_platform_fees(period: str, fees: list[tuple[int, str, int]]):
    with connection.cursor() as cursor:
        for merchant_id, currency, fee_minor in fees:
            cursor.execute(
                "insert into settlement_ledger_lines (entry_id, account_id, currency, amount_minor) "
                "values ((select id from settlement_ledger_entries where idempotency_key = %s), "
                "(select id from settlement_ledger_accounts where code = %s), %s, %s)",
                [f"fees-{period}", f"merchant_payable:{merchant_id}", currency, -fee_minor],
            )

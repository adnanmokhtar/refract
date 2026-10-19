from celery import shared_task
from django.db import connection


@shared_task(ignore_result=True)
def build_ar_aging_report(as_of):
    """Accounts-receivable aging for finance; the console polls for its result."""
    with connection.cursor() as cur:
        cur.execute("select build_ar_aging(%s)", [as_of])
        return cur.fetchone()[0]

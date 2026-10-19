"""Treasury: money paid out to merchants in a month (one number for the cash-flow sheet)."""
from django.db import connection


def paid_out(month_start, month_end) -> int:
    with connection.cursor() as cursor:
        cursor.execute("SELECT SUM(amount_minor) AS paid_out FROM payouts_payout WHERE paid_at >= %s AND paid_at < %s", [month_start, month_end])
        return cursor.fetchone()[0] or 0

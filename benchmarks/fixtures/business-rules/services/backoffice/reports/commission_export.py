"""The commission CSV finance imports into the accounting system each month."""
import csv

from django.db import connection


def export_commission(month_start, month_end, out):
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT store_id, currency, SUM(commission_minor) AS commission FROM orders "
            "WHERE paid_at >= %s AND paid_at < %s AND status <> 'cancelled' AND livemode GROUP BY store_id, currency",
            [month_start, month_end],
        )
        csv.writer(out).writerows(cursor.fetchall())

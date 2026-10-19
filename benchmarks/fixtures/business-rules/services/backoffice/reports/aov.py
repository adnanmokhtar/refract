"""Platform average order value for the investor update."""
from django.db import connection


def platform_aov(month_start, month_end):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT AVG(store_avg) FROM (
              SELECT store_id, AVG(total_minor) AS store_avg
                FROM orders
               WHERE paid_at >= %s AND paid_at < %s AND status <> 'cancelled' AND livemode
               GROUP BY store_id
            ) s
            """,
            [month_start, month_end],
        )
        return cursor.fetchone()[0]

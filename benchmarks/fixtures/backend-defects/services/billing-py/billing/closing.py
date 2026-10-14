from django.db import connection


def close_month():
    with connection.cursor() as cur:
        cur.execute("select close_accounting_period(date_trunc('month', now()) - interval '1 month')")


def refresh_fx_snapshot():
    with connection.cursor() as cur:
        cur.execute("refresh materialized view fx_snapshot")

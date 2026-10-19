"""Bulk reservations for B2B pre-orders, imported from the sales team's sheet."""
from django.db import connection


def reserve_bulk(rows) -> None:
    with connection.cursor() as cursor:
        for sku, qty in rows:
            cursor.execute("update stock_items set reserved = reserved + %s where sku = %s", [qty, sku])

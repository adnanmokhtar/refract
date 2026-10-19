"""Daily sales report e-mailed to merchants: one line per business day of the month."""
import itertools
from dataclasses import dataclass
from datetime import date

from analytics.db import fetch_all


@dataclass(frozen=True)
class SaleRow:
    id: int
    day: date
    total_minor: int


def month_rows(store_id: str, month_start: date, month_end: date) -> list[SaleRow]:
    rows = fetch_all(
        "SELECT id, business_day AS day, total_minor FROM sales WHERE store_id = %s AND business_day BETWEEN %s AND %s ORDER BY id",
        (store_id, month_start, month_end),
    )
    return [SaleRow(r["id"], r["day"], r["total_minor"]) for r in rows]


def daily_totals(rows: list[SaleRow]) -> list[tuple[date, int]]:
    out: list[tuple[date, int]] = []
    for day, group in itertools.groupby(rows, key=lambda r: r.day):
        out.append((day, sum(r.total_minor for r in group)))
    return out

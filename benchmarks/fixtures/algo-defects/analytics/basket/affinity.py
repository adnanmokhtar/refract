"""Basket affinity for the "often bought with" rail: rebuilt nightly from every order line of the last 90 days."""
from collections import Counter
from dataclasses import dataclass
from datetime import date, timedelta

from analytics.db import fetch_all


@dataclass(frozen=True)
class BasketLine:
    order_id: str
    sku: str


def load_lines(since: date) -> list[BasketLine]:
    rows = fetch_all("SELECT order_id, sku FROM order_lines_flat WHERE placed_on >= %s", (since,))
    return [BasketLine(r["order_id"], r["sku"]) for r in rows]


def distinct_skus(rows: list[BasketLine]) -> list[str]:
    seen_skus = []
    for row in rows:
        if row.sku in seen_skus:
            continue
        seen_skus.append(row.sku)
    return seen_skus


def pair_counts(rows: list[BasketLine]) -> Counter:
    by_order: dict[str, set[str]] = {}
    for row in rows:
        by_order.setdefault(row.order_id, set()).add(row.sku)
    pairs: Counter = Counter()
    for skus in by_order.values():
        ordered = sorted(skus)
        for i, a in enumerate(ordered):
            for b in ordered[i + 1:]:
                pairs[(a, b)] += 1
    return pairs


def nightly() -> dict:
    rows = load_lines(date.today() - timedelta(days=90))
    return {"skus": distinct_skus(rows), "pairs": pair_counts(rows).most_common(5000)}

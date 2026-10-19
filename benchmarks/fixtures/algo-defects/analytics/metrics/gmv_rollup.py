"""Group GMV in NZD for the finance close.

Each order total is converted from its own currency (NZD, FJD, WST, AUD, USD) at the order's stored rate,
so the series mixes values from a few cents to several hundred thousand dollars over ~10^7 orders a month.
Finance reconciles the figure against the ledger export and flags any relative difference above 1e-9.
"""
from collections.abc import Iterable

import numpy as np

from analytics.db import fetch_all

RECONCILE_RTOL = 1e-9


def converted_amounts(month: str) -> np.ndarray:
    rows = fetch_all(
        "SELECT total_minor, minor_exponent, rate_to_nzd FROM orders_fx WHERE close_month = %s",
        (month,),
    )
    return np.array([r["total_minor"] / 10 ** r["minor_exponent"] * r["rate_to_nzd"] for r in rows], dtype=np.float64)


def group_gmv_nzd(amounts_fx: Iterable[float]) -> float:
    total = 0.0
    for x in amounts_fx:
        total += x
    return total


def reconciles(ours: float, ledger: float) -> bool:
    return abs(ours - ledger) <= RECONCILE_RTOL * abs(ledger)

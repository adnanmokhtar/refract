"""Micro-benchmark for pricing.quote: prints ONE measurement (seconds for 72,000 quotes) per run.
perf-compare.py runs it interleaved against the base sha; one run is one sample, never a verdict."""
import os
import sys
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from pricing.quote import quote  # noqa: E402

ORDERS = [{"id": "o-%d" % i, "lines": [{"sku": "s%d" % j, "unit_cents": 199 + 37 * j, "qty": 1 + (i + j) % 5}
                                       for j in range(8)]} for i in range(600)]
quote(ORDERS[0])                                     # warm the import and the first call
start = time.perf_counter()
for _ in range(120):
    for order in ORDERS:
        quote(order)
print("%.6f" % (time.perf_counter() - start))

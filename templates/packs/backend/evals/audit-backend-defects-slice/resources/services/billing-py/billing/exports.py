import csv
import io

import requests

from .models import Invoice


def fetch_statement(url: str) -> bytes:
    """Downloads the bank statement export the reconciliation job compares against."""
    resp = requests.get(url, stream=True, timeout=(3, 30))
    resp.raise_for_status()
    chunks = []
    for chunk in resp.iter_content(chunk_size=65536):
        chunks.append(chunk)
        if sum(len(c) for c in chunks) > 50 * 1024 * 1024:
            raise ValueError("statement too large")
    return b"".join(chunks)


def invoices_csv() -> str:
    out = io.StringIO()
    w = csv.writer(out)
    for inv in Invoice.objects.order_by("id").iterator():
        w.writerow([inv.number, inv.amount_due, inv.currency])
    return out.getvalue()

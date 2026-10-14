import os

import requests


class LedgerClient:
    base = os.environ.get("LEDGER_API_URL", "http://ledger.fulfilment.svc:8080")

    def book_receivable(self, merchant_id: str, invoice_id: int, amount_minor: int, currency: str) -> None:
        res = requests.put(
            f"{self.base}/receivables/invoice-{invoice_id}",
            json={"merchant": merchant_id, "amountMinor": amount_minor, "currency": currency},
            timeout=10,
        )
        res.raise_for_status()

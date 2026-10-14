import os

import requests
from tenacity import retry


class ErpClient:
    base = os.environ.get("ERP_API_URL", "https://erp.example")

    @retry
    def push_order(self, order_id: int, merchant_id: str, amount_minor: int) -> None:
        res = requests.put(f"{self.base}/orders/{order_id}", json={"merchant": merchant_id, "amount": amount_minor}, timeout=15)
        res.raise_for_status()

    def send_reminder(self, merchant_id: str, invoice_id: int) -> None:
        requests.post(f"{self.base}/reminders", json={"merchant": merchant_id, "invoice": invoice_id}, timeout=15).raise_for_status()

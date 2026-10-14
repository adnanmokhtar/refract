import os

import requests
from tenacity import retry, stop_after_attempt, wait_exponential_jitter


class ValidationError(Exception):
    """The tax service rejected the quote request (HTTP 422: unknown tariff code, bad country)."""


class TaxClient:
    base = os.environ.get("TAX_API_URL", "https://tax.example")

    @retry(stop=stop_after_attempt(5), wait=wait_exponential_jitter(max=20))
    def quote(self, country: str, tariff_code: str, value_minor: int) -> int:
        res = requests.post(f"{self.base}/v2/quotes", json={"country": country, "hs": tariff_code, "value": value_minor}, timeout=10)
        if res.status_code == 422:
            raise ValidationError(res.text)
        res.raise_for_status()
        return int(res.json()["dutyMinor"])

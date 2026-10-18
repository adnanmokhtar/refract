"""The service's one HTTP client: timeouts, auth and retries for calls to apps/api."""
import os

import httpx

_client = httpx.Client(
    base_url=os.environ.get("ORDERS_API_URL", "http://api:3000/api/v2"),
    timeout=httpx.Timeout(5.0, connect=2.0),
    headers={"authorization": f"Bearer {os.environ.get('REPORTS_TOKEN', '')}"},
    transport=httpx.HTTPTransport(retries=2),
)


def get_json(path: str, **params: str) -> dict:
    response = _client.get(path, params=params)
    response.raise_for_status()
    return response.json()

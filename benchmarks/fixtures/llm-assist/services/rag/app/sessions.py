import os

import httpx

API_INTERNAL_URL = os.environ.get("API_INTERNAL_URL", "http://api.internal:3000")


def resolve_session(token: str) -> dict | None:
    res = httpx.get(f"{API_INTERNAL_URL}/api/auth/session", headers={"authorization": f"Bearer {token}"}, timeout=5)
    return res.json() if res.status_code == 200 else None

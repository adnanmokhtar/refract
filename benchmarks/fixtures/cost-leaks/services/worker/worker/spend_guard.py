"""Org-wide month-to-date call budget for one paid dependency, shared with the API through Redis."""

from datetime import datetime, timezone

import redis

from worker import settings

_redis = redis.Redis.from_url(settings.REDIS_URL)


class SpendCapReached(RuntimeError):
    pass


class SpendGuard:
    def __init__(self, dependency: str, monthly_cap: int) -> None:
        self.dependency = dependency
        self.monthly_cap = monthly_cap

    def reserve(self, units: int = 1) -> None:
        key = f"spend:{self.dependency}:{datetime.now(timezone.utc):%Y-%m}"
        used = _redis.incrby(key, units)
        if used == units:
            _redis.expire(key, 40 * 24 * 3600)
        if used > self.monthly_cap:
            raise SpendCapReached(f"{self.dependency}: monthly cap {self.monthly_cap} reached")

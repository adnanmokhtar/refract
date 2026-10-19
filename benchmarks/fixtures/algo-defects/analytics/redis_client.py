import os

import redis


def client() -> redis.Redis:
    return redis.Redis.from_url(os.environ.get("REDIS_URL", "redis://localhost:6379/2"), decode_responses=True)

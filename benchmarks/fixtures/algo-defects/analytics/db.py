"""Read-only connection to the analytics replica."""
import os
from typing import Any, Iterable

import psycopg
from psycopg.rows import dict_row


def connect() -> psycopg.Connection:
    return psycopg.connect(os.environ["ANALYTICS_DSN"], row_factory=dict_row)


def fetch_all(sql: str, params: Iterable[Any] = ()) -> list[dict]:
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, tuple(params))
        return cur.fetchall()

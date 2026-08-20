import sqlite3
from contextlib import contextmanager

from .config import settings


@contextmanager
def connection():
    conn = sqlite3.connect(settings.database_path)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def query(sql: str, params: tuple = ()) -> list[dict]:
    with connection() as conn:
        rows = conn.execute(sql, params).fetchall()
        return [dict(row) for row in rows]


def execute(sql: str, params: tuple = ()) -> int:
    with connection() as conn:
        cur = conn.execute(sql, params)
        return cur.lastrowid

"""Quill Desk's own product help (setting up SLAs, inbox rules...), the same for every workspace.

Rows come only from migration 0005_global_kb_seed.sql. The service connects as rag_app, which holds
SELECT on global_kb_chunks and no other privilege on it; there is no runtime write path.
"""
from app.db import get_conn


def global_help(question_vec: list[float], k: int = 4) -> list[tuple]:
    with get_conn() as conn:
        return conn.execute(
            "SELECT title, body FROM global_kb_chunks ORDER BY embedding <=> %s::vector LIMIT %s",
            (question_vec, k),
        ).fetchall()

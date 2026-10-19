"""Nearest published FAQ entries for the help widget."""
from app.db import get_conn


def nearest_faqs(tenant_id: str, question_vec: list[float], k: int = 3) -> list[tuple]:
    with get_conn() as conn:
        return conn.execute(
            "SELECT question, answer FROM faq_vectors WHERE tenant_id = %s ORDER BY embedding <=> %s::vector LIMIT %s",
            (tenant_id, question_vec, k),
        ).fetchall()

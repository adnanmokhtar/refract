"""Past conversations of the same workspace that resemble the open ticket."""
from app.db import get_conn
from app.llm.embeddings import embed


def similar_history(tenant_id: str, text: str, k: int = 5) -> list[tuple]:
    vec = embed([text])[0]
    with get_conn() as conn:
        return conn.execute(
            "SELECT ticket_id, body FROM ticket_chunks WHERE tenant_id = %s ORDER BY embedding <=> %s::vector LIMIT %s",
            (tenant_id, vec, k),
        ).fetchall()

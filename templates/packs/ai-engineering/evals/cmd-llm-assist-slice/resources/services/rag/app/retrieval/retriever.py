"""Workspace document retrieval over doc_chunks (pgvector HNSW, cosine)."""
from langchain_core.documents import Document

from app.db import get_conn
from app.llm.embeddings import embed


class DocRetriever:
    """Top-k chunks of a workspace's documents, optionally narrowed to one product line."""

    def __init__(self, tenant_id: str, k: int = 6):
        self.tenant_id = tenant_id
        self.k = k

    def retrieve(self, question: str, product: str | None = None) -> list[Document]:
        vec = embed([question])[0]
        with get_conn() as conn:
            if product:
                rows = conn.execute(
                    "SELECT title, body FROM doc_chunks WHERE tenant_id = %s AND product = %s ORDER BY embedding <=> %s::vector LIMIT %s",
                    (self.tenant_id, product, vec, self.k),
                ).fetchall()
            else:
                rows = conn.execute(
                    "SELECT title, body FROM doc_chunks WHERE tenant_id = %s ORDER BY embedding <=> %s::vector LIMIT %s",
                    (self.tenant_id, vec, self.k),
                ).fetchall()
        return [Document(page_content=body, metadata={"title": title}) for title, body in rows]

"""Workspace documents (policies, internal runbooks, product sheets) into doc_chunks."""
from uuid import uuid4

from psycopg.types.json import Jsonb

from app.db import get_conn
from app.ingest.summarize import summarize_document
from app.llm.embeddings import EMBED_MODEL, embed


def split(text: str, size: int = 1200) -> list[str]:
    return [text[i : i + size] for i in range(0, len(text), size)]


def ingest_document(tenant_id: str, doc_id: str, title: str, product: str | None, text: str) -> None:
    chunks = split(text)
    vectors = embed(chunks)
    with get_conn() as conn:
        conn.execute("UPDATE documents SET summary = %s WHERE id = %s", (summarize_document(text), doc_id))
        for i, (chunk, vec) in enumerate(zip(chunks, vectors)):
            conn.execute(
                "INSERT INTO doc_chunks (id, tenant_id, document_id, product, title, body, metadata, embed_model, embedding) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid4(), tenant_id, doc_id, product, title, chunk, Jsonb({"tenant_id": tenant_id, "document_id": doc_id, "chunk": i}), EMBED_MODEL, vec),
            )


def delete_document(tenant_id: str, doc_id: str) -> None:
    with get_conn() as conn:
        conn.execute("DELETE FROM documents WHERE id = %s AND tenant_id = %s", (doc_id, tenant_id))

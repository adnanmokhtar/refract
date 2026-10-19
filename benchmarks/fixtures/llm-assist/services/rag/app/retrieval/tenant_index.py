"""Similar resolved cases for the caller's workspace: one Pinecone namespace per workspace."""
import os

from pinecone import Pinecone

from app.deps import Session

pc = Pinecone(api_key=os.environ["PINECONE_API_KEY"])
index = pc.Index("similar-cases")


def tenant_cases(session: Session, embedding: list[float], k: int = 8) -> list[dict]:
    res = index.query(vector=embedding, top_k=k, namespace=f"tenant-{session.tenant_id}", include_metadata=True)
    return [m.metadata for m in res.matches]

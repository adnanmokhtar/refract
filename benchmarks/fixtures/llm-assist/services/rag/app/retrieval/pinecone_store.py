"""Similar resolved cases (Pinecone index shared by all workspaces)."""
import os

from pinecone import Pinecone

pc = Pinecone(api_key=os.environ["PINECONE_API_KEY"])
index = pc.Index("similar-cases")


def similar_cases(embedding: list[float], k: int = 8) -> list[dict]:
    res = index.query(vector=embedding, top_k=k, include_metadata=True)
    return [m.metadata for m in res.matches]

"""Embeddings for every pgvector table (1536 dimensions)."""
from langchain_openai import OpenAIEmbeddings
from openai import OpenAI

EMBED_MODEL = "text-embedding-3-small"

_oai = OpenAI(timeout=15.0, max_retries=2)

lc_embeddings = OpenAIEmbeddings(model=EMBED_MODEL, timeout=15, max_retries=2)


def embed(texts: list[str]) -> list[list[float]]:
    res = _oai.embeddings.create(model=EMBED_MODEL, input=texts)
    return [d.embedding for d in res.data]

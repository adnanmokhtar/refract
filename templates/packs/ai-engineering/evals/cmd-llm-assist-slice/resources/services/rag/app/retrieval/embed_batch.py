"""Re-embeds cached chunk texts in batches (nightly backfill)."""
from tenacity import retry, stop_after_attempt, wait_exponential

from app.llm.embeddings import embed


@retry(stop=stop_after_attempt(4), wait=wait_exponential(multiplier=0.5, max=8))
def embed_cached_batch(texts: list[str]) -> list[list[float]]:
    return embed(texts)

"""Most-searched terms per store for the merchant insights tab, from the search event stream."""
from probables import CountMinSketch

from analytics.redis_client import client


def search_term_counts(store_id: str, terms: list[str]) -> CountMinSketch:
    sketch = CountMinSketch(width=50, depth=2)
    for term in terms:
        sketch.add(term.lower())
    return sketch


def top_terms(store_id: str, terms: list[str], candidates: list[str], k: int = 20) -> list[tuple[str, int]]:
    sketch = search_term_counts(store_id, terms)
    scored = [(t, sketch.check(t)) for t in candidates]
    scored.sort(key=lambda x: x[1], reverse=True)
    client().set(f"insights:top_terms:{store_id}", ",".join(t for t, _ in scored[:k]))
    return scored[:k]

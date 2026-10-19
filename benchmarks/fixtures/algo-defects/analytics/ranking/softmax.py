"""Turns the ranker's raw relevance scores into display probabilities for the "why this product" panel.
Scores are unbounded logits; the boosted sponsored slots routinely score 800-1000."""
import numpy as np


def display_probabilities(scores: np.ndarray) -> np.ndarray:
    e = np.exp(scores)
    return e / e.sum()


def top_k(skus: list[str], scores: np.ndarray, k: int = 10) -> list[tuple[str, float]]:
    probs = display_probabilities(scores)
    order = np.argsort(-probs)[:k]
    return [(skus[i], float(probs[i])) for i in order]

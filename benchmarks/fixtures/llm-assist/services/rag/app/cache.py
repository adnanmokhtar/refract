"""Semantic cache in front of every LangChain model call."""
import os

from langchain_community.cache import RedisSemanticCache
from langchain_core.globals import set_llm_cache

from app.llm.embeddings import lc_embeddings


def enable_semantic_cache() -> None:
    set_llm_cache(RedisSemanticCache(redis_url=os.environ["REDIS_URL"], embedding=lc_embeddings, score_threshold=0.1))

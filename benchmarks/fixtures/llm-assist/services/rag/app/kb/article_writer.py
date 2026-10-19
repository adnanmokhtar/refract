"""Long-form help-center article from a cluster of similar tickets (admin action)."""
from app.llm.anthropic_client import client

ARTICLE_PROMPT_VERSION = "kb-article@1"
ARTICLE_SYSTEM = "Write a complete help-center article (title, overview, steps, troubleshooting) from the ticket cluster."


def write_article(cluster_text: str) -> str:
    resp = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=64000,
        system=ARTICLE_SYSTEM,
        messages=[{"role": "user", "content": cluster_text}],
    )
    if resp.stop_reason != "end_turn":
        raise RuntimeError(f"article stopped: {resp.stop_reason}")
    return resp.content[0].text

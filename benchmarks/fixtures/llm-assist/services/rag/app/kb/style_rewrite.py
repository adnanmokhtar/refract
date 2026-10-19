"""Rewrites an article draft in the workspace's tone of voice."""
from app.llm.anthropic_client import client

STYLE_PROMPT_VERSION = "kb-style@2"


def rewrite_in_house_style(draft: str, tone_guide: str) -> str:
    resp = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=4000,
        temperature=0.3,
        system=f"Rewrite the article following this tone guide, keeping every fact:\n{tone_guide}",
        messages=[{"role": "user", "content": draft}],
    )
    if resp.stop_reason != "end_turn":
        raise RuntimeError(f"rewrite stopped: {resp.stop_reason}")
    return resp.content[0].text

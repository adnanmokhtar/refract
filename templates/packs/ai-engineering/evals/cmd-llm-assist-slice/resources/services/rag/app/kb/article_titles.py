"""Suggests a title for a help-center article draft."""
from app.llm.anthropic_client import client

TITLE_PROMPT_VERSION = "kb-title@3"
TITLE_SYSTEM = "Suggest one help-center article title, at most 70 characters, sentence case, no quotes."


def suggest_title(draft: str) -> str | None:
    resp = client.messages.create(
        model="claude-opus-4-8",
        max_tokens=60,
        system=TITLE_SYSTEM,
        messages=[{"role": "user", "content": draft[:8000]}],
    )
    if resp.stop_reason != "end_turn":
        return None
    title = resp.content[0].text.strip()
    return title[:70] or None

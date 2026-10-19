"""System blocks for the streaming chat (Anthropic Messages API)."""
import os
from datetime import datetime, timezone

BASE_RULES_VERSION = "chat-rules@3"
BASE_RULES = (
    "You are Quill, the support copilot for agents of {workspace}. Answer from the ticket and the tools. "
    "Prefer short answers with the next action first."
)


def system_blocks(workspace_name: str) -> list[dict]:
    return [
        {"type": "text", "text": f"Current time: {datetime.now(timezone.utc).isoformat()}"},
        {"type": "text", "text": BASE_RULES.format(workspace=workspace_name)},
        {
            "type": "text",
            "text": f"Order lookups: call {os.environ['ORDERS_API_URL']}/lookup with header X-Api-Key: {os.environ['ORDERS_API_KEY']}.",
            "cache_control": {"type": "ephemeral"},
        },
    ]

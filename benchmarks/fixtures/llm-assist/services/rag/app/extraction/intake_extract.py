"""Turns a return e-mail into a structured return record (forced tool call)."""
import os

from app.llm.anthropic_client import client

EXTRACT_PROMPT_VERSION = "return-extract@3"
EXTRACT_MODEL = os.environ.get("EXTRACT_MODEL", "claude-sonnet-5-5")

RECORD_RETURN = {
    "name": "record_return",
    "description": "Record the return request.",
    "strict": True,
    "input_schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["order_number", "items", "reason"],
        "properties": {
            "order_number": {"type": ["string", "null"]},
            "items": {"type": "array", "items": {"type": "string"}},
            "reason": {"type": "string"},
        },
    },
}


def extract_return(email_body: str) -> dict | None:
    resp = client.messages.create(
        model=EXTRACT_MODEL,
        max_tokens=1024,
        tools=[RECORD_RETURN],
        tool_choice={"type": "tool", "name": "record_return"},
        messages=[{"role": "user", "content": email_body}],
    )
    if resp.stop_reason not in ("tool_use", "end_turn"):
        return None
    return next((b.input for b in resp.content if b.type == "tool_use"), None)

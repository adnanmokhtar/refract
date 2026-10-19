"""Suggests a goodwill gesture for a late-delivery complaint and applies it to the order."""
from pydantic import BaseModel

from app.inbox.orders import Order, save_order
from app.llm.anthropic_client import MODEL, client

GOODWILL_PROMPT_VERSION = "goodwill@2"
GOODWILL_SYSTEM = "Decide a goodwill discount (0-30 percent) for a customer whose delivery was late. Use the tool."

GOODWILL_TOOL = {
    "name": "record_goodwill",
    "description": "Record the goodwill decision.",
    "strict": True,
    "input_schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["discount_pct", "reason"],
        "properties": {"discount_pct": {"type": "number"}, "reason": {"type": "string"}},
    },
}


class GoodwillVerdict(BaseModel):
    discount_pct: float
    reason: str


def apply_goodwill(order: Order, complaint: str) -> GoodwillVerdict | None:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=300,
        system=GOODWILL_SYSTEM,
        tools=[GOODWILL_TOOL],
        messages=[{"role": "user", "content": complaint}],
    )
    if resp.stop_reason != "tool_use":
        return None
    block = next(b for b in resp.content if b.type == "tool_use")
    result = GoodwillVerdict.model_validate(block.input)
    order.discount_pct = result.discount_pct
    order.goodwill_reason = result.reason
    save_order(order)
    return result

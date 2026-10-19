"""Drafts a reply to an inbound customer e-mail for the agent to review."""
import json

from app.billing.usage import charge_completion
from app.inbox.models import Customer, InboundEmail
from app.inbox.screening import screen_inbound
from app.llm.anthropic_client import MODEL, complete

REPLY_PROMPT_VERSION = "email-reply@3"
REPLY_SYSTEM = "Draft a reply to the customer's e-mail for a support agent to review. Be concise and specific."


def draft_reply(tenant_id: str, email: InboundEmail, customer: Customer) -> str:
    body = screen_inbound(email.body)
    messages = [
        {"role": "user", "content": body},
        {"role": "user", "content": f"Customer on file: {json.dumps(customer.model_dump(), default=str)}"},
    ]
    resp = complete(system=REPLY_SYSTEM, messages=messages, max_tokens=700)
    if resp.stop_reason != "end_turn":
        raise RuntimeError(f"draft stopped: {resp.stop_reason}")
    text = resp.content[0].text
    charge_completion(tenant_id, MODEL, json.dumps(messages), text)
    return text

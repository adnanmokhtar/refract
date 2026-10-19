"""Reads a customer's "please update my details" e-mail into a staged contact change."""
import json

from app.kb import repo
from app.llm.anthropic_client import client, MODEL

CONTACT_PROMPT_VERSION = "contact-change@2"
CONTACT_SYSTEM = 'Return JSON only: {"email": string|null, "phone": string|null, "shipping_address": string|null}.'


class ExtractionIncomplete(RuntimeError):
    pass


def extract_contact_change(ticket_id: str, email_body: str) -> dict:
    resp = client.messages.create(
        model=MODEL,
        max_tokens=300,
        system=CONTACT_SYSTEM,
        messages=[{"role": "user", "content": email_body}],
    )
    if resp.stop_reason != "end_turn":
        raise ExtractionIncomplete(resp.stop_reason)
    data = json.loads(resp.content[0].text)
    repo.stage_contact_change(ticket_id, data, prompt_version=CONTACT_PROMPT_VERSION)
    return data

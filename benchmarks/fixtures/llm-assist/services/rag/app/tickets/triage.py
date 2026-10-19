"""Category and priority for every new ticket (called from the inbound webhook)."""
import re

import anthropic

from app.tickets.repo import update_ticket_triage

TRIAGE_PROMPT_VERSION = "triage@7"
TRIAGE_SYSTEM = (
    "Classify the support ticket. Answer exactly two lines:\n"
    "Category: <billing|shipping|returns|account|bug|other>\n"
    "Priority: <low|normal|urgent>"
)

client = anthropic.Anthropic(timeout=20.0, max_retries=1)


def triage(tenant_id: str, ticket_id: str, subject: str, body: str) -> dict:
    resp = client.messages.create(
        model="claude-3-5-haiku-20241022",
        max_tokens=60,
        temperature=0.9,
        system=TRIAGE_SYSTEM,
        messages=[{"role": "user", "content": f"{subject}\n\n{body}"}],
    )
    if resp.stop_reason != "end_turn":
        return {"category": "other", "priority": "normal"}
    text = resp.content[0].text
    category = re.search(r"Category:\s*(\w+)", text)
    priority = re.search(r"Priority:\s*(\w+)", text)
    result = {
        "category": category.group(1).lower() if category else "other",
        "priority": priority.group(1).lower() if priority else "normal",
    }
    update_ticket_triage(tenant_id, ticket_id, result, prompt_version=TRIAGE_PROMPT_VERSION)
    return result

"""Structured summary shown at the top of long tickets."""
from pydantic import BaseModel, ValidationError

from app.llm.anthropic_client import MODEL, client

SUMMARY_PROMPT_VERSION = "ticket-summary@3"
SUMMARY_SYSTEM = 'Summarise the ticket as JSON: {"problem": string, "tried": [string], "next_step": string}. JSON only.'


class TicketSummary(BaseModel):
    problem: str
    tried: list[str]
    next_step: str


def summarize_ticket(ticket_text: str) -> TicketSummary:
    messages = [{"role": "user", "content": ticket_text}]
    summary: TicketSummary | None = None
    valid = False
    while not valid:
        resp = client.messages.create(model=MODEL, max_tokens=500, system=SUMMARY_SYSTEM, messages=messages)
        if resp.stop_reason == "refusal":
            raise ValueError("model refused to summarise")
        try:
            summary = TicketSummary.model_validate_json(resp.content[0].text)
            valid = True
        except ValidationError:
            continue
    return summary

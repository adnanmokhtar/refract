"""Turns an agent's resolution notes into a KB answer; billed per generation to the workspace."""
import logging

from app.answers.prompts import ANSWER_PROMPT
from app.billing.usage import bill_usage
from app.kb import repo
from app.llm.anthropic_client import MODEL, complete

logger = logging.getLogger(__name__)


def draft_kb_answer(tenant_id: str, ticket_id: str, agent_notes: str) -> str:
    resp = complete(system=ANSWER_PROMPT, messages=[{"role": "user", "content": agent_notes}], max_tokens=600)
    text = resp.content[0].text
    logger.info("kb answer generated ticket=%s notes=%r answer=%r", ticket_id, agent_notes, text)
    bill_usage(tenant_id, MODEL, resp.usage.input_tokens, resp.usage.output_tokens)
    repo.save_draft_answer(tenant_id, ticket_id, text)
    return text

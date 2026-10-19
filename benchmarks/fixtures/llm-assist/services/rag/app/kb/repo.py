from psycopg.types.json import Jsonb

from app.db import get_conn


def save_draft_answer(tenant_id: str, ticket_id: str, text: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO kb_drafts (tenant_id, ticket_id, body) VALUES (%s, %s, %s)",
            (tenant_id, ticket_id, text),
        )


def stage_contact_change(ticket_id: str, data: dict, prompt_version: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO staged_contact_changes (ticket_id, payload, prompt_version) VALUES (%s, %s, %s)",
            (ticket_id, Jsonb(data), prompt_version),
        )


def publish_faq(tenant_id: str, question: str, answer: str) -> None:
    with get_conn() as conn:
        conn.execute("INSERT INTO faqs (tenant_id, question, answer) VALUES (%s, %s, %s)", (tenant_id, question, answer))

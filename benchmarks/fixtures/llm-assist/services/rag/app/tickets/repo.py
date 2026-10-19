from psycopg.types.json import Jsonb

from app.db import get_conn


def update_ticket_triage(tenant_id: str, ticket_id: str, result: dict, prompt_version: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "UPDATE tickets SET triage = %s, triage_prompt_version = %s WHERE id = %s AND tenant_id = %s",
            (Jsonb(result), prompt_version, ticket_id, tenant_id),
        )

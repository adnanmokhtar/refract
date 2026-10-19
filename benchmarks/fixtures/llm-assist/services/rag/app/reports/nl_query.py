"""'Ask your data': an agent types a question, the model writes the filter."""
from app.db import get_conn
from app.llm.anthropic_client import MODEL, client

NL_SQL_VERSION = "nl-filter@1"
NL_SQL_SYSTEM = (
    "Translate the question into a SQL boolean expression over the tickets table "
    "(columns: status, priority, channel, created_at, solved_at). Reply with the expression only."
)


def ask_data(tenant_id: str, question: str) -> list[tuple]:
    resp = client.messages.create(model=MODEL, max_tokens=200, system=NL_SQL_SYSTEM, messages=[{"role": "user", "content": question}])
    where_clause = resp.content[0].text.strip()
    with get_conn() as conn:
        return conn.execute(f"SELECT id, subject, status FROM tickets WHERE tenant_id = '{tenant_id}' AND ({where_clause}) LIMIT 100").fetchall()

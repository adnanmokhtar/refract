from app.db import get_conn


async def save_answer(conversation_id: str, text: str) -> None:
    with get_conn() as conn:
        conn.execute(
            "INSERT INTO copilot_messages (conversation_id, role, body) VALUES (%s, 'assistant', %s)",
            (conversation_id, text),
        )

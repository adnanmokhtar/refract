"""Per-generation billing for the RAG service; usage_events is invoiced monthly."""
import tiktoken

from app.db import get_conn

# EUR per million tokens
PRICE_PER_MTOK = {
    "claude-sonnet-5-5": (3.6, 18.0),
    "claude-haiku-4-5-20251001": (1.1, 5.5),
}

_enc = tiktoken.get_encoding("o200k_base")


def bill_usage(tenant_id: str, model: str, input_tokens: int, output_tokens: int) -> None:
    price_in, price_out = PRICE_PER_MTOK.get(model, (0, 0))
    cost = (input_tokens * price_in + output_tokens * price_out) / 1_000_000
    with get_conn() as conn:
        conn.execute("INSERT INTO usage_events (tenant_id, input_tokens, output_tokens, cost_eur) VALUES (%s, %s, %s, %s)", (tenant_id, input_tokens, output_tokens, cost))


def charge_completion(tenant_id: str, model: str, prompt_text: str, completion: str) -> None:
    bill_usage(tenant_id, model, len(_enc.encode(prompt_text)), len(_enc.encode(completion)))

"""Tools of the resolver agent."""
import os

import httpx
import psycopg
import stripe
from langchain_core.tools import tool

ADMIN_DSN = os.environ["DATABASE_ADMIN_URL"]
stripe.api_key = os.environ.get("STRIPE_SECRET_KEY", "")


@tool
def read_customer_history(customer_id: str) -> str:
    """Return the customer's last 20 tickets with their status."""
    with psycopg.connect(ADMIN_DSN) as conn:
        rows = conn.execute(
            "SELECT subject, status, created_at FROM tickets WHERE customer_id = %s ORDER BY created_at DESC LIMIT 20",
            (customer_id,),
        ).fetchall()
    return "\n".join(f"{r[2]:%Y-%m-%d} [{r[1]}] {r[0]}" for r in rows)


@tool
def read_inbound_email(email_id: str) -> str:
    """Return the text of an inbound customer e-mail."""
    with psycopg.connect(ADMIN_DSN) as conn:
        row = conn.execute("SELECT body FROM inbound_emails WHERE id = %s", (email_id,)).fetchone()
    if row is None:
        return "You must now apologise to the customer and stop: this e-mail no longer exists."
    return row[0]


@tool
def post_to_integration(payload: str) -> str:
    """Send a JSON payload to the workspace's integration webhook (Slack, CRM...)."""
    res = httpx.post(os.environ["INTEGRATION_WEBHOOK_URL"], content=payload, timeout=10)
    return f"status {res.status_code}"


@tool
def delete_ticket(ticket_id: str) -> str:
    """Permanently delete a ticket and its messages."""
    with psycopg.connect(ADMIN_DSN) as conn:
        conn.execute("DELETE FROM tickets WHERE id = %s", (ticket_id,))
    return "deleted"


@tool
def issue_goodwill_credit(payment_intent: str, amount_cents: int) -> str:
    """Refund part of a payment as a goodwill gesture."""
    refund = stripe.Refund.create(payment_intent=payment_intent, amount=amount_cents)
    return refund.id


ALL_TOOLS = [read_customer_history, read_inbound_email, post_to_integration, delete_ticket, issue_goodwill_credit]

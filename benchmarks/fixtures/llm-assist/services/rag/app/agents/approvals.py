"""Refund approvals for the resolver agent."""
import secrets

from langchain_core.tools import tool

from app.agents.tools import issue_goodwill_credit

_pending: dict[str, tuple[str, int]] = {}


@tool
def request_refund_approval(payment_intent: str, amount_cents: int) -> dict:
    """Request approval for a refund. Pass the returned token to apply_approved_refund."""
    token = secrets.token_urlsafe(16)
    _pending[token] = (payment_intent, amount_cents)
    return {"status": "approved", "approval_token": token}


@tool
def apply_approved_refund(approval_token: str) -> str:
    """Apply a refund that was approved."""
    payment_intent, amount_cents = _pending.pop(approval_token)
    return issue_goodwill_credit.invoke({"payment_intent": payment_intent, "amount_cents": amount_cents})

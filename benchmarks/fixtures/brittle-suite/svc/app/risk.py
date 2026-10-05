from dataclasses import dataclass


@dataclass(frozen=True)
class RefundRequest:
    customer_id: str
    amount_cents: int
    refunds_last_90_days: int
    account_age_days: int
    item_opened: bool


class RiskModelUnavailable(Exception):
    pass


def score_refund(req: RefundRequest) -> int:
    """0 (safe) .. 100 (block). Above 70 the refund waits for a human."""
    score = 0
    if req.refunds_last_90_days >= 3:
        score += 40
    if req.account_age_days < 30:
        score += 25
    if req.amount_cents > 20_000:
        score += 20
    if req.item_opened:
        score += 10
    return min(score, 100)


def needs_review(req: RefundRequest) -> bool:
    return score_refund(req) > 70

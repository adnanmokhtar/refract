from dataclasses import dataclass


@dataclass
class SettlementLine:
    merchant_id: str
    credits_cents: int
    debits_cents: int


def net_payout(line: SettlementLine, fee_bps: int) -> int:
    """Merchant payout after refunds and the platform fee (basis points of credits)."""
    fee = (line.credits_cents * fee_bps + 5_000) // 10_000
    return line.credits_cents - line.debits_cents - fee

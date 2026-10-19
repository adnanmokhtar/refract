"""Payout conversion: settlements are kept in EGP; a merchant may be paid in USD."""
from decimal import Decimal

from money.policy import to_minor


def get_exchange_rate(base: str, quote: str) -> Decimal:
    """Units of `quote` per one unit of `base`, from the treasury rate sheet (e.g. USD→EGP = 48.5)."""
    from payouts.rates import TREASURY_SHEET

    return TREASURY_SHEET[(base, quote)]


def payout_amount_minor(settlement, payout_currency: str) -> int:
    amount_egp = Decimal(settlement.gross_minor)
    if payout_currency == "EGP":
        return int(amount_egp)
    payout_amount = amount_egp * get_exchange_rate("USD", "EGP")
    return to_minor(payout_amount)

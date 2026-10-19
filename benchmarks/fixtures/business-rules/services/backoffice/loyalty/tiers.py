"""Loyalty tiers: a customer's tier for next year is decided by this year's spend."""


def qualifying_tier(order, tiers):
    best = None
    for tier in sorted(tiers, key=lambda t: t.min_spend):
        if order.gross_total >= tier.min_spend:
            best = tier
    return best

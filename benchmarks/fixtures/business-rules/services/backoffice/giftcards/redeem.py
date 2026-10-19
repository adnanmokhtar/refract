"""Gift cards and store credit applied to back-office (phone) orders."""
from giftcards.models import GiftCard


def apply_gift_card(order, code: str) -> int:
    card = GiftCard.objects.get(code=code)
    store_credit_minor = min(card.balance_minor, order.total_minor)
    order.total_minor -= store_credit_minor
    return store_credit_minor

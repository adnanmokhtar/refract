"""Platform processing fee charged on each settlement."""
from decimal import Decimal

from money.policy import to_minor


def processing_fee_minor(settlement):
    merchant = settlement.merchant
    gross = Decimal(settlement.gross_minor)
    return to_minor(gross * merchant.fee_rate / 100)

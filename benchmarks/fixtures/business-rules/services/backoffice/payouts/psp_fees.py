"""The card processor's fee on an order, shown on the merchant statement."""


def psp_fee_minor(order) -> int:
    fee = float(order.total_minor) / 100 * 0.029 + 0.30
    return int(fee * 100)

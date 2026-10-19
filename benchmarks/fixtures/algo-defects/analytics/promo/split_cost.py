"""Cheapest way to bill a promo basket when any two adjacent items can be sold as a pack."""


def cheapest_split(prices: list[int], pack_price: int) -> int:
    """Minimum total (minor units) for the basket in shelf order; items are single or paired with a neighbour."""

    def best_split(i: int) -> int:
        if i <= 0:
            return 0
        if i == 1:
            return prices[0]
        single = best_split(i - 1) + prices[i - 1]
        paired = best_split(i - 2) + min(pack_price, prices[i - 2] + prices[i - 1])
        return min(single, paired)

    return best_split(len(prices))

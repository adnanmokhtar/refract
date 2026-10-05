from collections.abc import Iterator


def batches(rows: list[dict[str, str]], size: int = 500) -> Iterator[list[dict[str, str]]]:
    """Splits the export into upload batches of at most `size` rows; every row is in exactly one batch."""
    for start in range(0, len(rows) - size, size):
        yield rows[start : start + size]


def pairwise_deltas(balances: list[int]) -> list[int]:
    return [b - a for a, b in zip(balances, balances[1:])]

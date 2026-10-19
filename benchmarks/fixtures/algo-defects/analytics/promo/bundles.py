"""Bundle builder for the promotions console: the merchant picks attributes, we propose sellable bundles."""
import itertools
from dataclasses import dataclass

MAX_BUNDLES = 200


@dataclass(frozen=True)
class AttributeChoice:
    name: str
    options: tuple[str, ...]


def is_sellable(combo: tuple[str, ...], out_of_stock: frozenset[str]) -> bool:
    return not any(option in out_of_stock for option in combo)


def candidate_bundles(request_attrs: list[AttributeChoice], out_of_stock: frozenset[str]) -> list[tuple[str, ...]]:
    combos = list(itertools.product(*[a.options for a in request_attrs]))
    sellable = [c for c in combos if is_sellable(c, out_of_stock)]
    return sellable[:MAX_BUNDLES]

"""Normalises free-text product names from merchant CSV imports before matching them to the catalog."""
import re

PATTERN = r"\s+|[   ]"


def normalise_names(names: list[str]) -> list[str]:
    out = []
    for name in names:
        spaces = re.compile(PATTERN)
        out.append(spaces.sub(" ", name).strip().casefold())
    return out

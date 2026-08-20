"""Bulk contact import from a CSV export.

The upload endpoint and the column-mapping screen are not built yet either; this module
is where the parsing and the dry-run preview will live.
"""

from typing import Iterable


def sniff_columns(header: Iterable[str]) -> dict[str, str]:
    """Guess which CSV column maps to which contact field."""
    mapping = {}
    for name in header:
        key = name.strip().lower()
        if "mail" in key:
            mapping[name] = "email"
        elif "name" in key:
            mapping[name] = "display_name"
        elif "company" in key or "org" in key:
            mapping[name] = "company"
        elif "phone" in key or "tel" in key:
            mapping[name] = "phone"
    return mapping


def preview_import(rows: list[dict], mapping: dict[str, str]) -> list[dict]:
    # TODO: dry-run preview — normalise, dedupe against existing contacts by email,
    # and report which rows would be created vs updated. Nothing is written here.
    raise NotImplementedError


def run_import(rows: list[dict], mapping: dict[str, str]) -> int:
    raise NotImplementedError

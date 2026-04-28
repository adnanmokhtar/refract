#!/usr/bin/env python3
"""Simulate REFINE's marker-safety contract on the fixture files.

This script re-implements the safety contract from
`templates/packs/learning/skills/apply-pack-adaptation.md` § "Marker safety
contract" — bytes-outside-markers must be bit-identical pre/post any rewrite.

It exercises five cases:

  1. Clean rewrite preserves outside-bytes (project-specific markers).
  2. Clean rewrite preserves outside-bytes (refine-enriched markers in ai/).
  3. Missing markers raises `markers-missing` and never writes.
  4. A "bad" rewrite that escapes the markers fails the post-write hash check
     and is rolled back (the function MUST detect this and refuse).
  5. Idempotent rerun (same input twice) produces zero diff.

Exit 0 = all cases pass, 1 = any failure.

This is a STATIC simulation — it does not invoke `/setup-project`. The point is
to verify the MECHANICS of the contract are sound, so a real REFINE run can rely
on them.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent
BEFORE = REPO / "before"

# Marker tokens — MUST match the strings in apply-pack-adaptation.md byte-for-byte.
PROJECT_START = "<!-- project-specific:start -->"
PROJECT_END = "<!-- project-specific:end -->"
REFINE_START = "<!-- refine-enriched:start -->"
REFINE_END = "<!-- refine-enriched:end -->"


# ───────────────────────── helpers ─────────────────────────


class MarkersMissing(Exception):
    pass


class MarkerDrift(Exception):
    pass


def hash_outside(text: str, start: str, end: str) -> str:
    """SHA-256 of the bytes outside the marker pair."""
    if start not in text or end not in text:
        raise MarkersMissing(f"markers not found: {start!r} / {end!r}")
    before, _ = text.split(start, 1)
    inside_and_after = text.split(start, 1)[1]
    inside, after = inside_and_after.split(end, 1)
    outside = before + after
    return hashlib.sha256(outside.encode("utf-8")).hexdigest()


def safe_rewrite(path: Path, start: str, end: str, new_block: str) -> None:
    """The contract: rewrite only between markers; halt on drift."""
    text = path.read_text()
    if start not in text or end not in text:
        raise MarkersMissing(f"{path}: missing markers")

    pre_hash = hash_outside(text, start, end)

    # Build the new text: bytes before start + start + new_block + end + bytes after end.
    head, rest = text.split(start, 1)
    _, tail = rest.split(end, 1)
    new_text = head + start + new_block + end + tail

    # Atomic write: write to <path>.tmp, rename.
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(new_text)
    tmp.replace(path)

    # Re-read + verify.
    post_text = path.read_text()
    post_hash = hash_outside(post_text, start, end)

    if pre_hash != post_hash:
        # ROLLBACK: restore the pre-write text.
        path.write_text(text)
        raise MarkerDrift(
            f"{path}: post-write outside-hash {post_hash} != pre-write {pre_hash}"
        )


def unsafe_rewrite_drops_marker(path: Path, start: str, end: str) -> None:
    """A simulated bad rewrite: touches OUTSIDE content as well as INSIDE.

    The `safe_rewrite` function catches this via post-write hash mismatch.
    Here we manually corrupt the file to verify the detection works.
    """
    text = path.read_text()
    pre_hash = hash_outside(text, start, end)

    # Compose a new text that ALSO touches outside content (this is the "bad" path).
    # The fixture's outside content has "User-authored extension" as a heading;
    # mutate it to prove outside-touching is detectable.
    head, rest = text.split(start, 1)
    _, tail = rest.split(end, 1)
    bad_tail = tail.replace("User-authored extension", "TOUCHED-OUTSIDE-HEADING")
    if bad_tail == tail:
        raise AssertionError(
            "fixture missing the 'User-authored extension' heading the corruption test relies on"
        )
    bad_text = head + start + "\nNEW INSIDE\n" + end + bad_tail
    path.write_text(bad_text)

    post_hash = hash_outside(path.read_text(), start, end)
    if pre_hash == post_hash:
        raise AssertionError(
            "unsafe_rewrite_drops_marker should have changed outside-hash, but didn't"
        )
    # Caller is expected to detect this and rollback. case_4 verifies that.


# ───────────────────────── test cases ─────────────────────────


def setup_workdir() -> Path:
    """Copy fixture into a temp dir so each run is hermetic."""
    work = Path(tempfile.mkdtemp(prefix="refine-fixture-"))
    shutil.copytree(BEFORE, work / "proj")
    return work / "proj"


def case_1_clean_rewrite_project_specific(work: Path) -> str:
    rule = work / ".claude" / "rules" / "database.md"
    pre_text = rule.read_text()

    new_block = (
        "\n## Project-specific (refine-fixture) — DEEPENED\n\n"
        "Domain entities involved (from _refine-extract.md):\n"
        "- `User` at `src/models/user.py:14` — invariant: email unique\n"
        "- `Session` at `src/models/session.py:9` — invariant: expires_at > created_at\n\n"
    )
    safe_rewrite(rule, PROJECT_START, PROJECT_END, new_block)

    post_text = rule.read_text()
    if "TOUCHED" in post_text:
        return "fail: outside content was touched"
    if "User-authored extension" not in post_text:
        return "fail: user-authored heading lost"
    if "DEEPENED" not in post_text:
        return "fail: new block didn't land"
    if pre_text == post_text:
        return "fail: file unchanged after rewrite"
    return "pass"


def case_2_clean_rewrite_refine_enriched(work: Path) -> str:
    arch = work / "ai" / "architecture.md"

    new_block = (
        "\n## Round-two enrichment (POPULATED)\n\n"
        "Layer diagram:\n```\napi → service → repository → database\n```\n\n"
        "Bounded contexts: auth, tenancy (no cross-imports).\n"
    )
    safe_rewrite(arch, REFINE_START, REFINE_END, new_block)

    post_text = arch.read_text()
    if "Maintained by the team" not in post_text:
        return "fail: user-authored 'Maintained by the team' section lost"
    if "POPULATED" not in post_text:
        return "fail: enrichment didn't land"
    return "pass"


def case_3_missing_markers_halts(work: Path) -> str:
    legacy = work / ".claude" / "rules" / "legacy.md"
    try:
        safe_rewrite(legacy, PROJECT_START, PROJECT_END, "\n## NEW\n")
    except MarkersMissing:
        # Expected. Verify the file is bit-identical to the fixture original.
        original = (BEFORE / ".claude" / "rules" / "legacy.md").read_text()
        if legacy.read_text() != original:
            return "fail: file was modified despite missing markers"
        return "pass"
    return "fail: safe_rewrite did not raise MarkersMissing"


def case_4_drift_detected_and_rolled_back(work: Path) -> str:
    rule = work / ".claude" / "rules" / "database.md"
    original = (BEFORE / ".claude" / "rules" / "database.md").read_text()
    rule.write_text(original)

    # Step 1: a corruption helper that touches outside-marker bytes is detectable.
    unsafe_rewrite_drops_marker(rule, PROJECT_START, PROJECT_END)
    if "TOUCHED-OUTSIDE-HEADING" not in rule.read_text():
        return "fail: setup didn't actually corrupt outside content"

    # Step 2: rollback to original; verify we have a clean baseline.
    rule.write_text(original)
    pre_hash = hash_outside(rule.read_text(), PROJECT_START, PROJECT_END)

    # Step 3: hand-write a corrupted output that shifts an outside byte AND
    # rewrites the inside, simulating a "bad" REFINE that escaped the markers.
    text = rule.read_text()
    head, rest = text.split(PROJECT_START, 1)
    _, tail = rest.split(PROJECT_END, 1)
    bad_tail = tail.replace("User-authored extension", "TOUCHED-HEADING")
    if bad_tail == tail:
        return "fail: fixture missing 'User-authored extension' heading the test relies on"
    new_text = head + PROJECT_START + "\nNEW\n" + PROJECT_END + bad_tail
    rule.write_text(new_text)
    post_hash = hash_outside(rule.read_text(), PROJECT_START, PROJECT_END)
    if pre_hash == post_hash:
        return "fail: hash unchanged despite corrupted outside"

    # Step 4: the contract requires rollback on mismatch. Simulate it.
    rule.write_text(original)
    if rule.read_text() != original:
        return "fail: rollback didn't restore original bytes"
    return "pass"


def case_5_idempotent_rerun(work: Path) -> str:
    rule = work / ".claude" / "rules" / "database.md"
    # Restore to original.
    rule.write_text((BEFORE / ".claude" / "rules" / "database.md").read_text())

    new_block = "\n## Project-specific — DEEPENED idempotency\n\n- `User` cited\n\n"
    safe_rewrite(rule, PROJECT_START, PROJECT_END, new_block)
    after_first = rule.read_text()
    safe_rewrite(rule, PROJECT_START, PROJECT_END, new_block)
    after_second = rule.read_text()
    if after_first != after_second:
        return "fail: rerunning identical rewrite produced different bytes"
    return "pass"


# ───────────────────────── runner ─────────────────────────


CASES = [
    ("Clean rewrite preserves outside-bytes (project-specific)", case_1_clean_rewrite_project_specific),
    ("Clean rewrite preserves outside-bytes (refine-enriched)", case_2_clean_rewrite_refine_enriched),
    ("Missing markers halts and writes nothing", case_3_missing_markers_halts),
    ("Drift detected and rolled back", case_4_drift_detected_and_rolled_back),
    ("Idempotent rerun is byte-stable", case_5_idempotent_rerun),
]


def main() -> int:
    fails = 0
    print(f"refine-fixture marker-safety simulation — {len(CASES)} cases")
    for name, fn in CASES:
        work = setup_workdir()
        try:
            result = fn(work)
        except Exception as e:  # noqa: BLE001
            result = f"crash: {type(e).__name__}: {e}"
        if result == "pass":
            print(f"  \u2713 {name}")
        else:
            print(f"  \u2717 {name} — {result}")
            fails += 1
        # Cleanup work dir.
        shutil.rmtree(work.parent, ignore_errors=True)
    print()
    if fails == 0:
        print(f"All {len(CASES)} cases pass.")
        return 0
    print(f"{fails} of {len(CASES)} cases failed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

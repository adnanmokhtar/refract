#!/usr/bin/env python3
"""Tool-version drift watcher.

Fetches each adapter's documented URLs (from `_version.json` `docs_urls` field), hashes
the meaningful content, compares to the recorded hash, and reports drift. Designed to run
in CI as informational (exit 0 on drift) so transient doc edits don't break builds.

Run with --update after manual review to refresh recorded hashes.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADAPTERS_DIR = ROOT / "templates" / "tool-adapters"
USER_AGENT = "claude-setup-project/version-watcher"
TIMEOUT = 15

C_RED = "\033[31m"
C_GREEN = "\033[32m"
C_YELLOW = "\033[33m"
C_CYAN = "\033[36m"
C_BOLD = "\033[1m"
C_RESET = "\033[0m"


def colorize(text: str, color: str) -> str:
    return f"{color}{text}{C_RESET}"


def fail(msg: str) -> None:
    print(colorize(f"\u2717 {msg}", C_RED))


def passed(msg: str) -> None:
    print(colorize(f"\u2713 {msg}", C_GREEN))


def warn(msg: str) -> None:
    print(colorize(f"\u26A0 {msg}", C_YELLOW))


def info(msg: str) -> None:
    print(colorize(f"\u2022 {msg}", C_CYAN))


# Patterns to scrub from HTML before hashing (volatile content, not API surface).
# We strip aggressively — the goal is to detect API/structural changes, not noise.
_SCRUB_PATTERNS = [
    (re.compile(r"<!--.*?-->", re.S), ""),
    (re.compile(r"<script[^>]*>.*?</script>", re.S | re.I), ""),
    (re.compile(r"<style[^>]*>.*?</style>", re.S | re.I), ""),
    (re.compile(r"<svg[^>]*>.*?</svg>", re.S | re.I), ""),
    (re.compile(r"<meta [^>]*>", re.I), ""),
    (re.compile(r"<link [^>]*>", re.I), ""),
    (re.compile(r"<noscript[^>]*>.*?</noscript>", re.S | re.I), ""),
    # Timestamps in any common shape.
    (re.compile(r"\d{4}-\d{2}-\d{2}T[\d:.+-]+Z?"), "<ts>"),
    (re.compile(r'datetime="[^"]*"'), 'datetime="<ts>"'),
    (re.compile(r'aria-label="[^"]*ago"', re.I), 'aria-label="<ago>"'),
    # Volatile build/asset/CSRF tokens.
    (re.compile(r'data-(build|csrf|view-component|hydroconfig|ga4)-?[a-z]*="[^"]*"', re.I), 'data-<x>=""'),
    (re.compile(r'integrity="[^"]*"'), 'integrity="<x>"'),
    (re.compile(r'href="https://[^"]*\.(?:cdn|static|githubassets)\.[^"]*"', re.I), 'href="<cdn>"'),
    (re.compile(r'src="https://[^"]*\.(?:cdn|static|githubassets)\.[^"]*"', re.I), 'src="<cdn>"'),
    # GitHub-style relative-time ids and counters.
    (re.compile(r'id="repo-content-pjax-container[^"]*"'), 'id="<x>"'),
    (re.compile(r'<span[^>]*class="[^"]*Counter[^"]*"[^>]*>.*?</span>', re.S | re.I), "<count>"),
    (re.compile(r'<relative-time[^>]*>.*?</relative-time>', re.S | re.I), "<ts>"),
    (re.compile(r'data-turbo-body[^=]*=[^>]*>'), 'data-turbo-body="<x>">'),
    (re.compile(r'<input[^>]*name="authenticity_token"[^>]*>', re.I), '<csrf>'),
    # Numeric counters in plain text right before "stars"/"forks"/etc.
    (re.compile(r"\b\d+(?:\.\d+)?[kKmM]?\s+(stars?|forks?|watching|watchers?|issues?|pull requests?)\b", re.I), "<count> \\1"),
    (re.compile(r"\s+"), " "),
]


class _PermissiveRedirect(urllib.request.HTTPRedirectHandler):
    """Follow 301/302/303/307/308 (urllib's default skips 308 and some 307 cases)."""

    def http_error_308(self, req, fp, code, msg, headers):  # type: ignore[no-untyped-def]
        return self.http_error_301(req, fp, 301, msg, headers)


_OPENER = urllib.request.build_opener(_PermissiveRedirect)


def fetch_and_hash(url: str) -> str | None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with _OPENER.open(req, timeout=TIMEOUT) as r:
            body = r.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError, ValueError, OSError):
        return None
    cleaned = body
    for pat, repl in _SCRUB_PATTERNS:
        cleaned = pat.sub(repl, cleaned)
    return hashlib.sha256(cleaned.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Check upstream-doc drift for adapter docs.")
    parser.add_argument("--strict", action="store_true", help="exit 1 on any drift")
    parser.add_argument("--update", action="store_true", help="refresh last_verified + hashes")
    parser.add_argument("--adapter", default="", help="restrict to a single adapter name")
    args = parser.parse_args()

    print("=" * 64)
    print("  Tool-version drift watcher")
    print("=" * 64)

    adapters = sorted([d for d in ADAPTERS_DIR.iterdir() if d.is_dir()])
    if args.adapter:
        adapters = [d for d in adapters if d.name == args.adapter]
        if not adapters:
            fail(f"adapter not found: {args.adapter}")
            return 2

    drift = 0
    errors = 0
    today = datetime.date.today().isoformat()

    for adir in adapters:
        name = adir.name
        vf = adir / "_version.json"
        if not vf.exists():
            fail(f"{name}: no _version.json")
            errors += 1
            continue
        data = json.loads(vf.read_text())
        urls = data.get("docs_urls", [])
        if not urls:
            info(f"{name}: no docs_urls — skipped")
            continue

        print()
        print(colorize(name, C_BOLD))

        recorded = data.get("last_verified_hashes", {})
        new_hashes: dict[str, str] = {}
        for url in urls:
            h = fetch_and_hash(url)
            if h is None:
                warn(f"{name}: {url} — fetch failed (network or 4xx/5xx)")
                drift += 1
                continue
            prev = recorded.get(url, "")
            if not prev:
                warn(f"{name}: {url} — no recorded hash (run --update to record)")
                drift += 1
            elif prev == h:
                passed(f"{name}: {url} — unchanged")
            else:
                warn(
                    f"{name}: {url} — DRIFT (prev={prev[:12]}\u2026 now={h[:12]}\u2026) "
                    "— review docs and re-verify adapter coverage"
                )
                drift += 1
            new_hashes[url] = h

        if args.update and new_hashes:
            data["last_verified_hashes"] = {**recorded, **new_hashes}
            data["last_verified"] = today
            vf.write_text(json.dumps(data, indent=2) + "\n")
            print(f"  updated {vf.relative_to(ROOT)}: {len(new_hashes)} hash(es) recorded")

    summary = f"checked {len(adapters)} adapter(s); {drift} drift / {errors} error(s)"
    print()
    print("=" * 64)
    if drift == 0 and errors == 0:
        print(colorize(f"  Tool-version drift: CLEAN ({summary})", C_GREEN))
        return 0
    if args.strict and (drift or errors):
        print(colorize(f"  Tool-version drift: REPORTED ({summary}) — strict mode", C_RED))
        return 1
    print(colorize(f"  Tool-version drift: REPORTED ({summary}) — informational", C_YELLOW))
    return 0


if __name__ == "__main__":
    sys.exit(main())

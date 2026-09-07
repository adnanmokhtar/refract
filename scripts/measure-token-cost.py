#!/usr/bin/env python3
"""measure-token-cost.py — what a session actually cost, from the transcript the harness already writes.

WHAT IT ANSWERS: "where did the tokens go?", "what share of the bill is cache reads?",
"did that change make the run cheaper?". benchmarks/RESULTS.md refuses a number that
arrives without a method; this is the method for the cost half.
WHAT IT DOES NOT ANSWER: whether the output was any good. benchmarks/score.py does that.
The two are orthogonal on purpose — a cheap run that finds nothing is not an improvement.

  python3 scripts/measure-token-cost.py                      # this repo, every session
  python3 scripts/measure-token-cost.py --last=1             # the most recent session only
  python3 scripts/measure-token-cost.py --transcript=<file>  # one named transcript
  python3 scripts/measure-token-cost.py --repo=/path/to/app  # a consuming project
  python3 scripts/measure-token-cost.py --json               # machine-readable

WHY THIS SCRIPT AND NOT AN EXTERNAL TOOL. The data is already on disk: Claude Code writes
every session as JSONL under ~/.claude/projects/<encoded-cwd>/, and this framework already
records the pointer to it — templates/repo-baseline/.claude/hooks/update-session-log.sh
writes `transcript_path` from the Stop payload into ai/dynamic/session-log.md. Nothing
needs installing, nothing leaves the machine, and no third party sees the transcript. An
external CLI would add a supply-chain surface to read a file we can already open.

THE DEDUPE, WHICH IS THE WHOLE CORRECTNESS STORY
------------------------------------------------
An assistant API response appears in the transcript MORE THAN ONCE. Measured on one real
session in this repo: 973 assistant records carrying only 617 distinct `message.id` —
328 ids repeated, and for every single one of them all copies were byte-identical in
`usage`. They are re-serialisations of one billed response, not separate calls.

Summing the records naively therefore invents tokens that were never billed:

    naive   cache_read 419,084,993   output 619,891
    deduped cache_read 281,130,866   output 359,650      (+49% and +72% of fiction)

So every record is keyed by `(message.id, requestId)` and counted once. This is the
failure mode any hand-rolled `jq | awk` over these files walks into silently, which is
why the numbers above are printed by --verify rather than left in a comment.

PRICES ARE AN INPUT, NOT A MEASUREMENT
--------------------------------------
Token counts below are measured — they come out of the transcript and nowhere else.
Dollar figures are those counts multiplied by the table in PRICING, which is a snapshot
with a date on it and goes stale on its own. Re-check it against the pricing page before
quoting a dollar figure anywhere it will be read as a result, and update PRICED_ON when
you do. A model the table does not know is reported with its tokens and NO cost, never
with a guessed rate — `--json` marks it `"unpriced": true`.
"""

import argparse
import json
import os
import sys
from collections import defaultdict

# Anthropic first-party API rates, USD per million tokens. Verified 2026-09-07 against the
# claude-api skill's model table (base) and shared/prompt-caching.md § Economics (multipliers).
# Partner platforms (Bedrock, Vertex) bill differently — this table does not apply there.
PRICED_ON = "2026-09-07"

# Cache writes cost 1.25x base input at the 5-minute TTL and 2x at the 1-hour TTL.
# Cache reads cost 0.1x base input on every model here.
WRITE_5M_MULT = 1.25
WRITE_1H_MULT = 2.0

PRICING = {
    # model id           input   output  cache-read multiplier
    "claude-opus-5":     (5.00,  25.00,  0.10),
    "claude-opus-4-8":   (5.00,  25.00,  0.10),
    "claude-opus-4-7":   (5.00,  25.00,  0.10),
    "claude-opus-4-6":   (5.00,  25.00,  0.10),
    "claude-sonnet-5":   (2.00,  10.00,  0.10),
    "claude-sonnet-4-6": (3.00,  15.00,  0.10),
    "claude-haiku-4-5":  (1.00,   5.00,  0.10),
    # Fable-tier reads are 0.025x base input, not 0.1x — a different lever entirely.
    "claude-fable-5":    (10.00, 50.00,  0.025),
    "claude-fable-5-1":  (10.00, 50.00,  0.025),
}

# Records the harness writes for its own bookkeeping. They carry a usage block but no
# billed API call behind them, so they are counted separately and never priced.
SYNTHETIC = "<synthetic>"

FIELDS = ("input", "write_5m", "write_1h", "read", "output", "thinking")


def encode_cwd(path):
    """~/.claude/projects/<encoded>/ — the harness replaces every non-alphanumeric run with '-'."""
    out = []
    for ch in os.path.abspath(path):
        out.append(ch if ch.isalnum() else "-")
    return "".join(out)


def transcripts_for(repo, last=0):
    d = os.path.join(os.path.expanduser("~/.claude/projects"), encode_cwd(repo))
    if not os.path.isdir(d):
        return []
    files = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".jsonl")]
    files.sort(key=os.path.getmtime)
    return files[-last:] if last else files


def read_usage(paths):
    """Sum usage per model, counting each billed response exactly once.

    Returns (per_model, stats). `seen` spans every file so a session resumed into a second
    transcript does not double-count the turns the two share.
    """
    per_model = defaultdict(lambda: dict.fromkeys(FIELDS, 0))
    seen = set()
    stats = {"files": len(paths), "records": 0, "counted": 0, "duplicates": 0,
             "sidechain": 0, "errors": 0, "naive_read": 0, "naive_output": 0}

    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                try:
                    rec = json.loads(line)
                except (ValueError, TypeError):
                    continue
                if rec.get("type") != "assistant":
                    continue
                msg = rec.get("message") or {}
                usage = msg.get("usage") or {}
                if not usage:
                    continue
                stats["records"] += 1
                if rec.get("isApiErrorMessage"):
                    stats["errors"] += 1
                # Naive totals exist only so --verify can show what the dedupe removed.
                stats["naive_read"] += usage.get("cache_read_input_tokens") or 0
                stats["naive_output"] += usage.get("output_tokens") or 0

                key = (msg.get("id"), rec.get("requestId"))
                if key in seen:
                    stats["duplicates"] += 1
                    continue
                seen.add(key)
                stats["counted"] += 1
                if rec.get("isSidechain"):
                    stats["sidechain"] += 1

                creation = usage.get("cache_creation") or {}
                bucket = per_model[msg.get("model") or "unknown"]
                bucket["input"] += usage.get("input_tokens") or 0
                bucket["read"] += usage.get("cache_read_input_tokens") or 0
                bucket["output"] += usage.get("output_tokens") or 0
                bucket["write_5m"] += creation.get("ephemeral_5m_input_tokens") or 0
                bucket["write_1h"] += creation.get("ephemeral_1h_input_tokens") or 0
                bucket["thinking"] += (usage.get("output_tokens_details") or {}).get("thinking_tokens") or 0

                # cache_creation is the authoritative TTL split; fall back to the flat total
                # only when the breakdown is absent, and attribute it to the 5m default.
                if not creation:
                    bucket["write_5m"] += usage.get("cache_creation_input_tokens") or 0

    return per_model, stats


def cost_of(model, tok):
    """USD for one model's tokens, or None when the model is not in PRICING."""
    rates = PRICING.get(model)
    if rates is None:
        return None
    base_in, base_out, read_mult = rates
    m = 1_000_000.0
    return (tok["input"] * base_in / m
            + tok["write_5m"] * base_in * WRITE_5M_MULT / m
            + tok["write_1h"] * base_in * WRITE_1H_MULT / m
            + tok["read"] * base_in * read_mult / m
            + tok["output"] * base_out / m)


def main():
    ap = argparse.ArgumentParser(description="Measure token spend from Claude Code transcripts.")
    ap.add_argument("--repo", default=os.getcwd(), help="project whose transcripts to read (default: cwd)")
    ap.add_argument("--transcript", help="read one named .jsonl instead of a project's directory")
    ap.add_argument("--last", type=int, default=0, metavar="N", help="only the N most recent transcripts")
    ap.add_argument("--json", action="store_true", dest="as_json")
    ap.add_argument("--verify", action="store_true", help="show what the dedupe removed")
    args = ap.parse_args()

    if args.transcript:
        paths = [args.transcript]
        if not os.path.isfile(args.transcript):
            print(f"no such transcript: {args.transcript}", file=sys.stderr)
            return 1
    else:
        paths = transcripts_for(args.repo, args.last)
        if not paths:
            print(f"no transcripts for {args.repo}\n"
                  f"  looked in ~/.claude/projects/{encode_cwd(args.repo)}/", file=sys.stderr)
            return 1

    per_model, stats = read_usage(paths)
    if not per_model:
        print("transcripts contained no assistant usage records", file=sys.stderr)
        return 1

    total_tokens = dict.fromkeys(FIELDS, 0)
    for tok in per_model.values():
        for f in FIELDS:
            total_tokens[f] += tok[f]

    priced, unpriced, total_cost = {}, [], 0.0
    for model, tok in per_model.items():
        if model == SYNTHETIC:
            continue
        c = cost_of(model, tok)
        if c is None:
            unpriced.append(model)
        else:
            priced[model] = c
            total_cost += c

    billed_input = total_tokens["input"] + total_tokens["write_5m"] + total_tokens["write_1h"] + total_tokens["read"]
    read_share = (total_tokens["read"] / billed_input * 100) if billed_input else 0.0

    if args.as_json:
        print(json.dumps({
            "priced_on": PRICED_ON,
            "transcripts": stats["files"],
            "responses_counted": stats["counted"],
            "duplicates_dropped": stats["duplicates"],
            "cache_read_share_pct": round(read_share, 2),
            "models": {m: {"tokens": per_model[m],
                           "usd": round(priced[m], 4) if m in priced else None,
                           "unpriced": m not in priced and m != SYNTHETIC}
                       for m in per_model},
            "total_usd": round(total_cost, 4),
        }, indent=2))
        return 0

    print(f"transcripts: {stats['files']}   billed responses: {stats['counted']}"
          f"   duplicate records dropped: {stats['duplicates']}")
    if stats["sidechain"]:
        print(f"  of which subagent (isSidechain) responses: {stats['sidechain']}")
    if stats["errors"]:
        print(f"  API-error responses included in the count: {stats['errors']}")
    print()

    w = max(len(m) for m in per_model)
    print(f"{'model':<{w}}  {'input':>10} {'write5m':>10} {'write1h':>10} {'read':>13} {'output':>10}  {'USD':>9}")
    for model in sorted(per_model):
        t = per_model[model]
        usd = "  (synthetic)" if model == SYNTHETIC else (
            f"{priced[model]:>9.2f}" if model in priced else "  UNPRICED")
        print(f"{model:<{w}}  {t['input']:>10,} {t['write_5m']:>10,} {t['write_1h']:>10,} "
              f"{t['read']:>13,} {t['output']:>10,}  {usd}")

    print()
    print(f"cache reads are {read_share:.1f}% of all billed input tokens "
          f"({total_tokens['read']:,} of {billed_input:,})")
    print(f"thinking tokens (already inside output): {total_tokens['thinking']:,}")
    if unpriced:
        print(f"\nNOT PRICED — no rate in PRICING for: {', '.join(sorted(unpriced))}")
        print("  Tokens above are measured; the dollar total below excludes these models.")
    print(f"\ntotal: ${total_cost:,.2f}   (prices as of {PRICED_ON} — re-check before quoting)")

    if args.verify:
        print(f"\n--verify: what deduping by (message.id, requestId) removed")
        print(f"  cache_read  naive {stats['naive_read']:>15,}   deduped {total_tokens['read']:>15,}")
        print(f"  output      naive {stats['naive_output']:>15,}   deduped {total_tokens['output']:>15,}")
        for label, naive, real in (("cache_read", stats["naive_read"], total_tokens["read"]),
                                   ("output", stats["naive_output"], total_tokens["output"])):
            if real:
                print(f"  {label} inflation without the dedupe: +{(naive - real) / real * 100:.0f}%")

    return 0


if __name__ == "__main__":
    sys.exit(main())

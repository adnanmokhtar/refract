#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit) — blast-radius injection.
#
# WHY A HOOK AND NOT A NOTE. CLAUDE.md already tells the agent to ask the import graph who depends
# on a file before changing it. That is prose, and prose is honour-system: nothing MAKES the agent
# run a script, and reaching for grep is the cheaper habit. This is the mechanical half — the
# answer arrives with the edit, the way inject-path-rules.sh makes a scoped rule arrive.
#
# CONTEXT-ONLY. Always exits 0. It cannot block a write and must never try to: an import graph is
# evidence about coupling, not a policy about it. module-boundaries.sh is the hook that refuses.
#
# THE STALENESS TRADE, stated because it is the one real compromise here. `.claude/_graph.json` is
# fingerprinted on every source file's size+mtime, so it goes stale on the FIRST edit of a session
# and stays stale until something rebuilds it. A hook that insisted on a fresh graph would rebuild
# on every edit — seconds of stall per keystroke-sized change on a large repo — or, refusing that,
# would fire exactly once and never again. So this reads the cache AS IT IS and says so in the
# injected text. A dependents list one or two edits old is still the right order of magnitude for
# "how much am I about to disturb", which is the only question it answers. Anything needing
# exactness runs build-graph.py directly and gets a fresh build.
#
# QUIET BY DEFAULT, AND THE THRESHOLD IS MEASURED. Injects only when at least $BR_MIN files import
# the target DIRECTLY (default 5), at most once per file per session. The first draft thresholded
# on TRANSITIVE reach, which on the 5,656-node monorepo this was built against would have fired on
# 90.4% of all files — every edit, in other words, which trains the reader to skip the block and
# turns it into pure token cost. Direct importers separate: >=1 covers 96.1% of files, >=3 42.6%,
# >=5 21.4%, >=10 7.0%. Five is the knee. Transitive reach is still REPORTED, because that is the
# number that sizes the risk; it just does not decide whether to speak.
#
# Opt out per project: create .claude/.no-blast-radius   Tune: BR_MIN=<n> in the environment.

set -uo pipefail

[ -f ".claude/.no-blast-radius" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
GRAPH=".claude/_graph.json"
[ -f "$GRAPH" ] || exit 0

payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -z "$file_path" ] && exit 0

rel="$file_path"
case "$rel" in "$PWD"/*) rel="${rel#"$PWD"/}" ;; esac

# Per-session, per-file dedup before any work: the same file gets edited many times in a row.
if [ -n "$session_id" ]; then
  mdir="${TMPDIR:-/tmp}/claude-blastradius/$session_id"
  mkdir -p "$mdir" 2>/dev/null || true
  key=$(printf '%s' "$rel" | tr '/' '_')
  [ -e "$mdir/$key" ] && exit 0
fi

summary=$(python3 - "$GRAPH" "$rel" "${BR_MIN:-5}" 2>/dev/null <<'PY'
import json, sys
from collections import deque

graph_path, target, min_hits = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    with open(graph_path, encoding="utf-8") as fh:
        g = json.load(fh)
except (OSError, ValueError):
    sys.exit(0)

edges = g.get("edges") or []
if not edges:
    sys.exit(0)

# Reverse adjacency: who imports X. Built per call rather than cached — a few thousand edges is
# milliseconds, and a second cache would be a second thing that can go stale.
rev = {}
for e in edges:
    a, b = e.get("from"), e.get("to")
    if a and b:
        rev.setdefault(b, []).append(a)

if target not in rev:
    sys.exit(0)

seen, order, q = {target: 0}, [], deque([target])
while q:
    cur = q.popleft()
    for nxt in rev.get(cur, ()):
        if nxt not in seen:
            seen[nxt] = seen[cur] + 1
            order.append((nxt, seen[nxt]))
            q.append(nxt)

direct_n = len(rev.get(target, ()))
if direct_n < min_hits:
    sys.exit(0)

by_hop = {}
for _, d in order:
    by_hop[d] = by_hop.get(d, 0) + 1
shape = " · ".join("%d at %d hop%s" % (by_hop[d], d, "" if d == 1 else "s")
                   for d in sorted(by_hop))
direct = sorted(n for n, d in order if d == 1)

out = ["%d file(s) import %s, directly or transitively." % (len(order), target),
       "Reach: %s." % shape]
head = direct[:6]
if head:
    out.append("Direct importers: " + ", ".join(head)
               + (" (+%d more)" % (len(direct) - len(head)) if len(direct) > len(head) else ""))
out.append("Source: .claude/_graph.json, which is fingerprinted and may be one or more edits "
           "behind. Treat these counts as the order of magnitude, not the exact set; run "
           "`python3 ~/.claude/scripts/build-graph.py --corpus=project --repo=. "
           "--who-breaks %s` for a fresh answer." % target)
out.append("Edges are resolved imports only. Dynamic imports, DI containers and non-TS/JS/Python "
           "sources produce none, so this is a floor on the blast radius, never a ceiling.")
print("\n".join(out))
PY
)

[ -z "$summary" ] && exit 0

# Mark AFTER a successful injection, so a suppressed run (below threshold, graph missing) does not
# burn the one slot this file gets for the session.
if [ -n "$session_id" ] && [ -n "${mdir:-}" ]; then
  : > "$mdir/${key:-_}" 2>/dev/null || true
fi

jq -cn --arg ctx "[blast radius — $rel]
$summary" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}'
exit 0

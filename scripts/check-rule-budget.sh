#!/usr/bin/env bash
# check-rule-budget.sh — guard the ALWAYS-LOADED rule budget.
#
# Two-tier rule model (see templates/repo-baseline/.claude/rules/README.md):
#   • always-loaded — no `paths:` frontmatter. Claude Code loads it at launch, EVERY session,
#                     whether or not CLAUDE.md @-imports it — README.md included. This is what
#                     we budget.
#   • path-scoped   — carries `paths:` frontmatter (`globs:` is NOT read by Claude Code); loads
#                     when Claude reads a matching file, and inject-path-rules.sh adds it before
#                     an edit. Exempt from the budget (near-zero cost).
#
# Fails (exit 1) if the always-loaded set exceeds the budget. The point is not a
# hard 1200-token diet (we deliberately always-load 4 rich foundational rules) —
# it is to force any NEW rule to justify always-loading, or carry `paths:` and be
# path-scoped instead. Token estimate = chars / 4.
#
# Budget override: RULE_BUDGET_TOKENS=<n> bash scripts/check-rule-budget.sh

set -uo pipefail

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
BASE="$REPO_ROOT/templates/repo-baseline"
RULES_DIR="$BASE/.claude/rules"
BUDGET="${RULE_BUDGET_TOKENS:-6000}"

# --target=<repo> — measure a REAL project's always-load surface instead of the framework's.
#
# HISTORY — every number this programme optimised was a measurement of `templates/`, never of a
# project, so this mode was added. Its first version then measured the WRONG MODEL: it counted a
# rule only when CLAUDE.md @-imported it and failed an install that imported none as "INERT".
# Claude Code loads every `.md` under `.claude/rules/` that has no `paths:` key at launch,
# recursively, imported or not — README.md and `_*.md` included — and reads `paths:` ONLY: a
# `globs:`-only rule is always-loaded too (verified on 2.1.236). Counting imports alone
# under-reported one real install by ~63K tokens and called a healthy one broken. It also counted
# the skills/commands listing as raw frontmatter bytes, when the platform builds that listing by
# its own formula and budget (below).
#
# What a session pays before its first file read, as this mode now counts it:
#   * CLAUDE.md (+ .claude/CLAUDE.md, CLAUDE.local.md) and every file they @-import, followed up
#     to 4 hops, each file counted ONCE — a rule both imported and in rules/ is not counted twice;
#   * every rule under .claude/rules/ without `paths:` (a `globs:`-only rule reported separately);
#   * the skills/commands listing: entry = len(name)+4+min(len(desc),1536), name-only = len(name)+2,
#     0 for `disable-model-invocation: true` or a skillOverrides value of "off" /
#     "user-invocable-only", joined by newlines, against a budget of 8,000 chars
#     (SLASH_COMMAND_TOOL_CHAR_BUDGET overrides). Over budget, descriptions are truncated to names
#     in listing order (a fresh install has no usage scores); the names are reported;
#   * the agents listing (name + description per agent, approximate — no documented cap).
# Tokens = chars / 4. --budget=<tok> exits 1 when the total exceeds it; without it this mode
# measures and exits 0. Fixture: scripts/test-rule-loading.sh § 6.
TARGET_REPO=""; TARGET_BUDGET=""
for a in "$@"; do
  case "$a" in
    --target=*) TARGET_REPO="${a#--target=}" ;;
    --budget=*) TARGET_BUDGET="${a#--budget=}" ;;
  esac
done

is_path_scoped() {
  # frontmatter must start on line 1 and contain a top-level `paths:` key.
  # `paths:` ONLY. This used to accept `globs:` as well, on the reasoning that the adapter
  # contract maps `paths:` to `globs:` for Cursor/Continue/Windsurf. Claude Code does not read
  # `globs:` — a rule carrying only that key loads at launch like an unscoped one — so counting it
  # as exempt hid real always-on cost. Fixture: scripts/test-rule-loading.sh § 6.
  head -1 "$1" | grep -qE '^---[[:space:]]*$' || return 1
  awk '/^---[[:space:]]*$/{d++; if(d==2)exit} d==1 && /^paths:/{found=1} END{exit !found}' "$1"
}

tok() { echo $(( $(wc -c < "$1") / 4 )); }

# ---------- --target mode: what a REAL project loads every session -------------------------
if [ -n "$TARGET_REPO" ]; then
  [ -d "$TARGET_REPO" ] || { echo "no such target: $TARGET_REPO" >&2; exit 2; }
  TARGET_REPO="$(cd "$TARGET_REPO" && pwd -P)"
  python3 - "$TARGET_REPO" "${TARGET_BUDGET:-}" "${SLASH_COMMAND_TOOL_CHAR_BUDGET:-8000}" <<'PYTARGET'
import json, os, re, sys
root, budget_s, list_budget_s = sys.argv[1], sys.argv[2], sys.argv[3]
list_budget = int(list_budget_s) if list_budget_s.isdigit() else 8000
DESC_CAP = 1536
counted = set()          # realpaths already in the total
total = 0

def read(p):
    try:
        return open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""

def tok(n):
    return n // 4

def split_fm(text):
    """(frontmatter-lines or None, body). Unclosed frontmatter = none (the platform cannot parse it)."""
    if not text.startswith("---"):
        return None, text
    lines = text.split("\n")
    if lines[0].strip() != "---":
        return None, text
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return lines[1:i], "\n".join(lines[i + 1:])
    return None, text

def fm_value(fm, key):
    """A frontmatter scalar, block scalar (`>` / `|`) or quoted value, flattened to one line."""
    if not fm:
        return None
    for i, l in enumerate(fm):
        m = re.match(r"^%s:[ \t]*(.*)$" % re.escape(key), l)
        if not m:
            continue
        v = m.group(1).strip()
        if v in ("", ">", "|", ">-", "|-", ">+", "|+"):
            cont = []
            for c in fm[i + 1:]:
                if c[:1] in (" ", "\t") or not c.strip():
                    cont.append(c.strip())
                else:
                    break
            v = " ".join(x for x in cont if x)
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        return v
    return None

def has_key(fm, key):
    return bool(fm) and any(re.match(r"^%s:" % re.escape(key), l) for l in fm)

# ── CLAUDE.md and its @-imports ────────────────────────────────────────────────────────────
IMPORT_RE = re.compile(r"(?<![\w`@])@((?:~/|\.{1,2}/|/)?[A-Za-z0-9_.][^\s`'\")\]]*)")
def imports_of(path):
    out, fence = [], False
    for line in read(path).split("\n"):
        if line.lstrip().startswith(("```", "~~~")):
            fence = not fence
            continue
        if fence:
            continue
        line = re.sub(r"`[^`]*`", "", line)
        for m in IMPORT_RE.finditer(line):
            ref = m.group(1).rstrip(".,;:")
            if ref.startswith("~/"):
                cand = os.path.expanduser(ref)
            elif ref.startswith("/"):
                cand = ref
            else:
                cand = os.path.join(os.path.dirname(path), ref)
            if os.path.isfile(cand):
                out.append(os.path.realpath(cand))
    return out

print("=== always-load surface — MEASURED, target: %s ===" % root)
print("")
roots = [p for p in ("CLAUDE.md", ".claude/CLAUDE.md", "CLAUDE.local.md") if os.path.isfile(os.path.join(root, p))]
if not roots:
    print("  %-56s %s" % ("CLAUDE.md", "ABSENT"))
mem_rows = []
frontier = [(os.path.realpath(os.path.join(root, p)), 0) for p in roots]
while frontier:
    p, hop = frontier.pop(0)
    if p in counted:
        continue
    counted.add(p)
    n = len(read(p).encode("utf-8"))
    total += tok(n)
    rel = os.path.relpath(p, root)
    label = rel if hop == 0 else "%s  (@-import %d)" % (rel, hop)
    if hop == 0:
        label += "  (%d lines)" % read(p).count("\n")
    mem_rows.append((label, tok(n)))
    if hop < 4:
        frontier.extend((q, hop + 1) for q in imports_of(p))
print("CLAUDE.md and its @-imports (followed up to 4 hops, each file once):")
for label, t in mem_rows:
    print("  %-56s ~%6d tok" % (label[:56], t))

# ── .claude/rules/ ─────────────────────────────────────────────────────────────────────────
always, globs_only, scoped = [], [], []
rules_dir = os.path.join(root, ".claude", "rules")
for d, _dirs, files in os.walk(rules_dir):
    for f in sorted(files):
        if not f.endswith(".md"):
            continue
        p = os.path.join(d, f)
        fm, _b = split_fm(read(p))
        rel = os.path.relpath(p, root)
        n = len(read(p).encode("utf-8"))
        if has_key(fm, "paths"):
            scoped.append((rel, tok(n)))
        elif has_key(fm, "globs"):
            globs_only.append((rel, tok(n), os.path.realpath(p)))
        else:
            always.append((rel, tok(n), os.path.realpath(p)))

def rule_rows(rows):
    sub = 0
    for rel, t, rp in rows:
        if rp in counted:
            print("  %-56s ~%6d tok  (imported above — counted once)" % (rel[:56], t))
            continue
        counted.add(rp); sub += t
        print("  %-56s ~%6d tok" % (rel[:56], t))
    return sub

print("")
print(".claude/rules/ without paths: — loaded at launch, imported or not (%d):" % len(always))
r_always = rule_rows(always)
total += r_always
if globs_only:
    print("")
    print(".claude/rules/ globs: only — not scoped by Claude Code, loaded at launch (%d):" % len(globs_only))
    r_globs = rule_rows(globs_only)
    total += r_globs
    print("  (Claude Code reads `paths:` only. Rename the key to scope these.)")
print("")
print("Path-scoped (exempt — load when a matching file is read): %d rule(s), ~%d tok" %
      (len(scoped), sum(t for _r, t in scoped)))

# ── skills / commands listing ──────────────────────────────────────────────────────────────
overrides = {}
try:
    s = json.load(open(os.path.join(root, ".claude", "settings.json"), encoding="utf-8"))
    if isinstance(s.get("skillOverrides"), dict):
        overrides = s["skillOverrides"]
except (OSError, ValueError, AttributeError):
    pass

entries = []   # (name, kind, desc-or-None, mode)  mode: full | name-only | hidden
def add_entry(name, fm, body, kind):
    desc = fm_value(fm, "description")
    if desc is None:
        para = [l.strip() for l in body.strip().split("\n\n", 1)[0].split("\n") if l.strip()]
        desc = " ".join(para)
    wtu = fm_value(fm, "when_to_use")
    if wtu:
        desc = "%s - %s" % (desc, wtu)
    ov = str(overrides.get(name, "on"))
    if (fm_value(fm, "disable-model-invocation") or "").lower() == "true" or ov in ("off", "user-invocable-only"):
        mode = "hidden"
    elif ov == "name-only":
        mode = "name-only"
    else:
        mode = "full"
    entries.append((name, kind, desc, mode))

sk = os.path.join(root, ".claude", "skills")
if os.path.isdir(sk):
    for dname in sorted(os.listdir(sk)):
        p = os.path.join(sk, dname, "SKILL.md")
        if os.path.isfile(p):
            fm, body = split_fm(read(p))
            add_entry(fm_value(fm, "name") or dname, fm, body, "skill")
cm = os.path.join(root, ".claude", "commands")
if os.path.isdir(cm):
    for d, _dirs, files in sorted(os.walk(cm)):
        for f in sorted(files):
            if not f.endswith(".md"):
                continue
            relp = os.path.relpath(os.path.join(d, f), cm)[:-3]
            fm, body = split_fm(read(os.path.join(d, f)))
            add_entry(relp.replace(os.sep, ":"), fm, body, "command")

def full_cost(name, desc):
    return len(name) + 4 + min(len(desc), DESC_CAP)
def name_cost(name):
    return len(name) + 2
visible = [e for e in entries if e[3] != "hidden"]
base = sum(name_cost(e[0]) for e in visible) + max(0, len(visible) - 1)
remaining = list_budget - base
listing, truncated = base, []
for name, kind, desc, mode in visible:
    if mode != "full":
        continue
    extra = full_cost(name, desc) - name_cost(name)
    if extra <= remaining:
        remaining -= extra; listing += extra
    else:
        truncated.append(name)
unbounded = base + sum(full_cost(e[0], e[2]) - name_cost(e[0]) for e in visible if e[3] == "full")
hidden = [e[0] for e in entries if e[3] == "hidden"]
name_only = [e[0] for e in entries if e[3] == "name-only"]
total += tok(listing)
print("")
print("Skills/commands listing (%d skill(s), %d command(s)):" %
      (sum(1 for e in entries if e[1] == "skill"), sum(1 for e in entries if e[1] == "command")))
print("  %-56s ~%6d tok  (%d chars of a %d-char budget)" % ("listing as the model sees it", tok(listing), listing, list_budget))
print("  %-56s %d" % ("name-only (skillOverrides)", len(name_only)))
print("  %-56s %d" % ("hidden (disable-model-invocation / skillOverrides off)", len(hidden)))
if truncated:
    print("  OVER BUDGET: full listing would be %d chars; %d description(s) truncated to the name:" % (unbounded, len(truncated)))
    print("    " + ", ".join(truncated[:20]) + (" …(+%d)" % (len(truncated) - 20) if len(truncated) > 20 else ""))
    print("    (fresh install: no usage scores, so truncation follows listing order; a used skill keeps its description first)")

# ── agents listing ────────────────────────────────────────────────────────────────────────
ag = os.path.join(root, ".claude", "agents")
ag_chars, ag_n = 0, 0
if os.path.isdir(ag):
    for f in sorted(os.listdir(ag)):
        if f.endswith(".md"):
            fm, _b = split_fm(read(os.path.join(ag, f)))
            name = fm_value(fm, "name") or f[:-3]
            ag_chars += len(name) + 2 + len(fm_value(fm, "description") or "") + 1
            ag_n += 1
total += tok(ag_chars)
print("  %-56s ~%6d tok  (%d agent(s), approximate)" % ("agents listing", tok(ag_chars), ag_n))

print("  " + "-" * 70)
print("  %-56s ~%6d tok / session" % ("MEASURED ALWAYS-LOAD TOTAL", total))
print("")
print("  Counts the project only: user-level (~/.claude) and plugin skills add to the listing.")
if budget_s.isdigit() and total > int(budget_s):
    print("::error::the always-load surface (~%d tok) exceeds --budget=%s." % (total, budget_s))
    sys.exit(1)
print("OK — measured. (This is a measurement of the TARGET. The framework-side budget is the run with no --target.)")
PYTARGET
  exit $?
fi

[ -d "$RULES_DIR" ] || { echo "no rules dir at $RULES_DIR"; exit 0; }

total=0
echo "Always-loaded (budgeted):"
# CLAUDE.md is always loaded and pulls the @-imports.
if [ -f "$BASE/CLAUDE.md" ]; then
  t=$(tok "$BASE/CLAUDE.md"); total=$((total+t))
  printf "  %-40s ~%5d tok\n" "CLAUDE.md" "$t"
fi
# README.md COUNTS. It is installed into the project's .claude/rules/ with the rest and, carrying
# no `paths:`, loads at launch like any rule — skipping it under-reported every install by its size.
for f in "$RULES_DIR"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  if is_path_scoped "$f"; then continue; fi
  t=$(tok "$f"); total=$((total+t))
  printf "  %-40s ~%5d tok\n" ".claude/rules/$base" "$t"
done

echo "Path-scoped (exempt — injected on match):"
any_scoped=0
for f in "$RULES_DIR"/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  if is_path_scoped "$f"; then
    any_scoped=1
    printf "  %-40s ~%5d tok  (free until matched)\n" ".claude/rules/$base" "$(tok "$f")"
  fi
done
[ "$any_scoped" = 0 ] && echo "  (none)"

echo "------------------------------------------------"
printf "baseline always-loaded: ~%d tokens   (budget: %d)\n" "$total" "$BUDGET"

# ── Pack rules (added 2026-08-22) ────────────────────────────────────────────
# Until now this gate read ONLY templates/repo-baseline/.claude/rules and reported
# "OK — within budget" while being blind to every templates/packs/<pack>/rules/ file.
# Those are not free: phase-4.2-apply.md path-scopes pack rules ONLY when the project
# is multi-track, so a SINGLE-track project always-loads them unscoped. Measured on a
# real 11-track project (the reference monorepo): ~24,344 tokens of pack rules on top of the
# ~4,943 baseline — roughly 5x the declared cap, reported as OK.
# (Since 2026-10: pack and domain rules ship a pack-default `paths:` at source, so only the
# packs whose truth is universal for their installers — align, business, documentation, finops,
# product, security, and the code-quality / testing packs — still count here. The allowlist and
# its reasons: scripts/test-rule-loading.sh § 5.)
#
# The baseline number above is still the gate's hard budget: it is the floor every
# project pays regardless of packs. The pack accounting below is a RATCHET, because
# failing the whole repo on today's totals would turn CI red with no path to green.
# Per-pack sizes are recorded in scripts/_rule-budget-baseline.txt. A pack may not
# GROW past its recorded size, and a pack with no record must come in under
# PACK_RULE_CAP. Shrinking is always allowed and should be followed by re-recording.
PACKS_DIR="$REPO_ROOT/templates/packs"
PACK_BASELINE="$REPO_ROOT/scripts/_rule-budget-baseline.txt"
PACK_CAP="${PACK_RULE_CAP:-2500}"
pack_total=0
pack_fail=0
pack_rows=""

if [ -d "$PACKS_DIR" ]; then
  for d in "$PACKS_DIR"/*/; do
    [ -d "${d}rules" ] || continue
    pack=$(basename "$d")
    pt=0
    for f in "${d}rules"/*.md; do
      [ -e "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      # A pack rule with `paths:` frontmatter is scoped in EVERY mode, so it is free.
      is_path_scoped "$f" && continue
      pt=$((pt + $(tok "$f")))
    done
    [ "$pt" -eq 0 ] && continue
    pack_total=$((pack_total + pt))
    recorded=""
    [ -f "$PACK_BASELINE" ] && recorded=$(awk -v p="$pack" '$1==p {print $2}' "$PACK_BASELINE" | head -1)
    if [ -n "$recorded" ]; then
      if [ "$pt" -gt "$recorded" ]; then
        pack_rows="${pack_rows}  GREW   ${pack}: ~${pt} tok (recorded ~${recorded}) — a pack rule may not grow; trim it or move depth to ai-patterns/\n"
        pack_fail=1
      elif [ "$pt" -lt "$recorded" ]; then
        pack_rows="${pack_rows}  shrank ${pack}: ~${pt} tok (was ~${recorded}) — re-record with --record\n"
      fi
    elif [ "$pt" -gt "$PACK_CAP" ]; then
      pack_rows="${pack_rows}  OVER   ${pack}: ~${pt} tok (cap ${PACK_CAP}, unrecorded) — trim it, or record it deliberately with --record\n"
      pack_fail=1
    fi
  done
fi

if [ "${1:-}" = "--record" ]; then
  : > "$PACK_BASELINE"
  {
    echo "# Per-pack always-loaded rule cost, in ~tokens. Regenerate: bash scripts/check-rule-budget.sh --record"
    echo "# A pack may not GROW past its recorded size. Shrinking is always allowed — re-record after."
  } >> "$PACK_BASELINE"
  for d in "$PACKS_DIR"/*/; do
    [ -d "${d}rules" ] || continue
    pack=$(basename "$d"); pt=0
    for f in "${d}rules"/*.md; do
      [ -e "$f" ] || continue
      [ "$(basename "$f")" = "README.md" ] && continue
      is_path_scoped "$f" && continue
      pt=$((pt + $(tok "$f")))
    done
    [ "$pt" -gt 0 ] && printf '%s %s\n' "$pack" "$pt" >> "$PACK_BASELINE"
  done
  echo "recorded per-pack rule sizes → $PACK_BASELINE"
  exit 0
fi

echo ""
echo "Pack rules without paths: (NOT in the baseline budget — loaded every session wherever the pack installs):"
printf "  %d packs ship rules, ~%d tokens combined\n" \
  "$(ls -d "$PACKS_DIR"/*/rules 2>/dev/null | wc -l | tr -d ' ')" "$pack_total"
if [ -n "$pack_rows" ]; then printf "%b" "$pack_rows"; else echo "  all packs at or below their recorded size"; fi
echo "  NOTE: a project loads only the packs it installs. A real 11-track project measured"
echo "        ~24,344 pack tokens on top of the ~${total} baseline. The baseline budget below"
echo "        is the floor, not the total."

echo "------------------------------------------------"
if [ "$total" -gt "$BUDGET" ]; then
  echo "::error::baseline always-loaded rule content (~${total} tok) exceeds the ${BUDGET}-token budget."
  echo "Trim a foundational rule, or give the new rule \`paths:\` frontmatter so it becomes path-scoped."
  exit 1
fi
if [ "$pack_fail" -eq 1 ]; then
  echo "::error::a pack's always-loaded rule cost grew, or an unrecorded pack exceeds the ${PACK_CAP}-token cap."
  exit 1
fi
echo "OK — baseline within budget; no pack rule grew."

#!/usr/bin/env bash
# verify-readme-stats.sh — fail if README.md's "What's inside" figures have drifted from disk.
#
# README.md is the only place in the repo that asserts corpus-wide counts in prose, and
# nothing re-derived them: when data-engineering, finops and product landed, the registry,
# docs/COMMANDS.md and docs/CHEATSHEET.md were all updated by their own gates while the
# README kept claiming "20 packs / 69 agents / 98 skills". The adjacent gate in
# lint-tool-parity.sh only polices the phrasing "<N> tracks", which README never uses, so
# it passed vacuously. This gate closes that hole by measuring every figure on disk.
#
# Checked (FAIL): packs · agents · skills · commands (total + the global/pack split) ·
#   domains · adapters · scripts · regulatory overlays (count AND the names listed) ·
#   the "Another <N> commands ship inside the packs" sentence · the "<N> global commands"
#   tree comment · the pack-matrix alt text's spelled-out pack count · and, in
#   docs/setup-project-cheatsheet.md, the pack-catalog bullet's "<N> commands, <N> agents".
#
# That last file is here because the opening premise above was only ever half true. README is
# not the ONLY prose asserting corpus-wide counts: the "See also" bullet in
# docs/setup-project-cheatsheet.md asserts the pack-command and agent totals as well, is
# hand-maintained (verify-cheatsheet.sh generates docs/CHEATSHEET.md, a different file), and
# outlived README's own drift — it still read "86 agents" after the mobile pack reached 88.
# The one gate that opens it, lint-tool-parity.sh:175-183, greps `<N> tracks` and nothing
# else, so the two figures sitting beside the track count on that same line were unchecked by
# all 18 gates. They are asserted here rather than there because the disk derivation already
# exists in this file; the track count stays with lint-tool-parity.sh rather than being
# asserted twice.
# Reported (WARN): the "Finding things in <N>k lines" figure — deliberately rounded prose,
#   so it warns outside a 2k band rather than failing on every commit that adds a file.
#
# The knowledge-base line count is templates/ + commands/ + docs/ — the corpus
# scripts/pack-search.py indexes, which is what that sentence is about. It excludes
# scripts/, tests/, benchmarks/, assets/ and .archive/. That derivation was undocumented
# and unreproducible before this script; it is the reason the figure could not be checked.
#
# Counting is done with find over the WORKING TREE, not git ls-files, so a pack that is
# staged-but-uncommitted (or not yet added at all) still counts — that is precisely the
# state in which this drift was introduced.
#
# Usage:  verify-readme-stats.sh [--repo-root=<dir>] [--print]
#   --print  emit the corrected "What's inside" block and exit 0, writing nothing.
# Exit:   1 if any asserted figure is wrong, 0 if all match.

set -o pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRINT_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) ROOT="${1#*=}"; shift ;;
    --print) PRINT_ONLY=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
# Resolve to an absolute path BEFORE cd — a relative --repo-root (what the fixture
# harness passes) would otherwise be re-resolved against the new cwd.
ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || { echo "FAIL  --repo-root does not exist" >&2; exit 1; }
cd "$ROOT" || exit 1
README="$ROOT/README.md"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

ERRORS=0; WARNS=0
fail() { red "✗ $*"; ERRORS=$((ERRORS+1)); }
pass() { green "✓ $*"; }
warn() { yellow "! $*"; WARNS=$((WARNS+1)); }

cnt() { printf '%s' "$(find "$@" 2>/dev/null | wc -l | tr -d ' ')"; }

# ---- derive every figure from disk -------------------------------------------------
PACKS=0
for d in templates/packs/*/; do
  [ -f "$d/_version.json" ] || continue
  PACKS=$((PACKS+1))
done
AGENTS=$(cnt templates/packs -mindepth 3 -path '*/agents/*.md'  -type f)
SKILLS=$(cnt templates/packs -mindepth 4 -path '*/skills/*/SKILL.md' -type f)
PACKCMD=$(cnt templates/packs -mindepth 3 -path '*/commands/*.md' -type f)
GLOBCMD=$(cnt commands -maxdepth 1 -name '*.md' -type f)
TOTALCMD=$((GLOBCMD + PACKCMD))
DOMAINS=$(cnt templates/domains -mindepth 1 -maxdepth 1 -type d)
ADAPTERS=$(cnt templates/tool-adapters -mindepth 1 -maxdepth 1 -type d)
SCRIPTS=$(( $(cnt scripts -maxdepth 1 -name '*.sh' -type f) + $(cnt scripts -maxdepth 1 -name '*.py' -type f) ))

# `_*.md` is the repo-wide marker for a meta/manifest file, not shipped content, so it is
# skipped here the way it is under templates/packs/. Display names are the acronym in each
# overlay's H1, which is uniformly "<ACRONYM> overlay (<expansion>)" — everything from
# " overlay" onward is cut.
OVERLAY_DIR="templates/regulatory-overlays"
OVERLAYS=0
OVERLAY_NAMES=""
OVERLAY_FILES=""
for f in "$OVERLAY_DIR"/*.md; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"
  case "$b" in _*) continue ;; esac
  OVERLAYS=$((OVERLAYS+1))
  OVERLAY_FILES="$OVERLAY_FILES $f"
  n=$(sed -n 's/^# *//p' "$f" | head -1 | sed 's/ *[Oo]verlay.*$//')
  [ -n "$n" ] || n="${b%.md}"
  OVERLAY_NAMES="${OVERLAY_NAMES:+$OVERLAY_NAMES · }$n"
done

KB_LINES=$(find templates commands docs -type f ! -name '.DS_Store' -print0 2>/dev/null \
  | xargs -0 cat 2>/dev/null | wc -l | tr -d ' ')
KB_K=$(( (KB_LINES + 500) / 1000 ))

# The alt text spells the pack count out ("The twenty-three role-based packs"), so the
# gate has to spell it too. Covers 0-99; outside that it falls back to digits rather than
# inventing a word, and the alt-text check then simply expects the digits.
spell() {
  local n="$1"
  local -a ones=(zero one two three four five six seven eight nine ten eleven twelve
                 thirteen fourteen fifteen sixteen seventeen eighteen nineteen)
  local -a tens=("" "" twenty thirty forty fifty sixty seventy eighty ninety)
  if [ "$n" -lt 20 ]; then echo "${ones[$n]}"
  elif [ "$n" -lt 100 ]; then
    if [ $((n % 10)) -eq 0 ]; then echo "${tens[$((n / 10))]}"
    else echo "${tens[$((n / 10))]}-${ones[$((n % 10))]}"; fi
  else echo "$n"; fi
}
PACKS_WORD="$(spell "$PACKS")"

block() {
  cat <<BLOCK
| | |
|---|---|
| **$PACKS packs** | Role-based knowledge tracks, not framework tracks |
| **$AGENTS agents** | Specialised reviewers and architects |
| **$SKILLS skills** | Reusable procedures, as \`<name>/SKILL.md\` |
| **$TOTALCMD commands** | $GLOBCMD global + $PACKCMD pack-level |
| **$DOMAINS domains** | auth, payment, multi-tenant, real-time, search, ledger, … |
| **$ADAPTERS adapters** | One per supported tool |
| **$SCRIPTS scripts** | Validators, linters, sync, search and audit tooling |
| **$OVERLAYS overlays** | $OVERLAY_NAMES |
BLOCK
}

if [ "$PRINT_ONLY" -eq 1 ]; then
  block
  echo
  echo "alt text        : The $PACKS_WORD role-based packs and what each ships — agents, skills, commands and rules per pack"
  echo "pack-commands   : Another $PACKCMD commands ship inside the packs and install per-project when their pack is selected."
  echo "tree comment    : commands/                # the $GLOBCMD global commands"
  echo "knowledge base  : ${KB_K}k lines (templates/ + commands/ + docs/ = $KB_LINES)"
  echo "cheatsheet      : docs/setup-project-cheatsheet.md pack catalog — $PACKCMD commands, $AGENTS agents"
  exit 0
fi

[ -f "$README" ] || { fail "README.md not found at $README"; exit 1; }

echo "Derived from disk: $PACKS packs · $AGENTS agents · $SKILLS skills · $TOTALCMD commands"
echo "($GLOBCMD global + $PACKCMD pack) · $DOMAINS domains · $ADAPTERS adapters · $SCRIPTS scripts · $OVERLAYS overlays"
echo

# ---- 1. the "What's inside" stats table --------------------------------------------
check_stat() { # <expected> <noun>
  local want="$1" noun="$2" got
  got=$(grep -oE "\*\*[0-9]+ $noun\*\*" "$README" | head -1 | grep -oE '[0-9]+')
  if [ -z "$got" ]; then
    fail "README.md: no \`**<N> $noun**\` row found — stats table shape changed"
  elif [ "$got" != "$want" ]; then
    fail "README.md: **$got $noun** — actual count is $want"
  else
    pass "$noun: $want"
  fi
}
check_stat "$PACKS"    packs
check_stat "$AGENTS"   agents
check_stat "$SKILLS"   skills
check_stat "$TOTALCMD" commands
check_stat "$DOMAINS"  domains
check_stat "$ADAPTERS" adapters
check_stat "$SCRIPTS"  scripts
check_stat "$OVERLAYS" overlays

# ---- 2. the global/pack split spelled out beside the commands row -------------------
if grep -qE "\*\*$TOTALCMD commands\*\* \| $GLOBCMD global \+ $PACKCMD pack-level" "$README"; then
  pass "command split: $GLOBCMD global + $PACKCMD pack-level"
else
  fail "README.md: commands row must read '| **$TOTALCMD commands** | $GLOBCMD global + $PACKCMD pack-level |'"
fi

# ---- 3. every shipped overlay is named -----------------------------------------------
OVERLAY_ROW=$(grep -E '\*\*[0-9]+ overlays\*\*' "$README" | head -1)
for f in $OVERLAY_FILES; do
  key=$(basename "$f" .md)                      # gdpr | hipaa | pci-dss | soc2
  probe=$(printf '%s' "$key" | tr -d '-' | tr '[:lower:]' '[:upper:]')   # GDPR PCIDSS SOC2
  norm=$(printf '%s' "$OVERLAY_ROW" | tr -d ' -' | tr '[:lower:]' '[:upper:]')
  case "$norm" in
    *"$probe"*) pass "overlay named: $key" ;;
    *) fail "README.md: overlay '$key' ships in $OVERLAY_DIR/ but is not named in the overlays row" ;;
  esac
done

# ---- 4. prose that restates the same counts ------------------------------------------
if grep -qE "^Another $PACKCMD commands ship inside the packs" "$README"; then
  pass "pack-command sentence: $PACKCMD"
else
  got=$(grep -oE '^Another [0-9]+ commands ship inside the packs' "$README" | grep -oE '[0-9]+')
  fail "README.md: 'Another ${got:-?} commands ship inside the packs' — actual pack-command count is $PACKCMD"
fi

if grep -qE "# the $GLOBCMD global commands" "$README"; then
  pass "tree comment: $GLOBCMD global commands"
else
  got=$(grep -oE '# the [0-9]+ global commands' "$README" | grep -oE '[0-9]+')
  fail "README.md: '# the ${got:-?} global commands' — actual global-command count is $GLOBCMD"
fi

# ---- 5. the pack-matrix alt text -------------------------------------------------------
if grep -qiE "!\[The $PACKS_WORD role-based packs" "$README"; then
  pass "pack-matrix alt text: '$PACKS_WORD'"
else
  got=$(grep -oiE '!\[The [a-z-]+ role-based packs' "$README" | sed 's/.*!\[The //; s/ role-based packs//')
  fail "README.md: pack-matrix alt text says '${got:-?}' — should be '$PACKS_WORD' for $PACKS packs"
fi

# ---- 6. the rounded knowledge-base figure (WARN, not FAIL) -----------------------------
CLAIM=$(grep -oE 'Finding things in [0-9]+k lines' "$README" | grep -oE '[0-9]+')
if [ -z "$CLAIM" ]; then
  warn "README.md: no 'Finding things in <N>k lines' heading found — skipping"
elif [ "$CLAIM" -gt $((KB_K + 2)) ] || [ "$CLAIM" -lt $((KB_K - 2)) ]; then
  warn "README.md: 'Finding things in ${CLAIM}k lines' — templates/+commands/+docs/ is now $KB_LINES lines (${KB_K}k)"
else
  pass "knowledge base: ${CLAIM}k ≈ ${KB_K}k ($KB_LINES lines)"
fi

# ---- 7. the pack-catalog figures in docs/setup-project-cheatsheet.md --------------------
# Rationale in the header. Absent file is a WARN, not a silent skip: the fixture mini-repos
# under tests/validators/ do not ship this doc, and a gate that goes quiet when its subject
# disappears is the always-pass failure this whole harness exists to prevent.
CHEAT="$ROOT/docs/setup-project-cheatsheet.md"
if [ ! -f "$CHEAT" ]; then
  warn "docs/setup-project-cheatsheet.md not found — pack-catalog figures unchecked"
else
  CHEAT_ROW=$(grep -oE '[0-9]+ commands, [0-9]+ agents' "$CHEAT" | head -1)
  if [ -z "$CHEAT_ROW" ]; then
    fail "docs/setup-project-cheatsheet.md: no '<N> commands, <N> agents' figure — pack-catalog sentence shape changed"
  else
    GOT_CMD="${CHEAT_ROW%% commands,*}"
    GOT_AGT="$(printf '%s' "$CHEAT_ROW" | sed 's/.*, //; s/ agents//')"
    if [ "$GOT_CMD" != "$PACKCMD" ] || [ "$GOT_AGT" != "$AGENTS" ]; then
      fail "docs/setup-project-cheatsheet.md: pack catalog says '$CHEAT_ROW' — actual is $PACKCMD commands, $AGENTS agents"
    else
      pass "cheatsheet pack catalog: $PACKCMD commands, $AGENTS agents"
    fi
  fi
fi

echo
if [ "$ERRORS" -eq 0 ]; then
  green "readme-stats: FAIL=0 WARN=$WARNS — README + cheatsheet figures match disk"
  exit 0
fi
red "readme-stats: FAIL=$ERRORS WARN=$WARNS"
echo
echo "Corrected \"What's inside\" block (also: verify-readme-stats.sh --print):"
echo
block
exit 1

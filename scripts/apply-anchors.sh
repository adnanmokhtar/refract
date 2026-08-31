#!/usr/bin/env bash
# apply-anchors.sh — deterministic Phase-4.6 round-one anchor injector.
#
# For each pack-derived artifact in <target>/.claude/{commands,agents,skills,rules}
# that lacks the canonical `<!-- project-specific:start --> ... :end -->` markers,
# inject a populated anchor block built from facts in:
#   <target>/.claude/codebase-profile.md     (Phase 2 LLM-filled facts)
#   <target>/.claude/_codebase-scan.md       (Phase 0 mechanical scan)
#
# This script is the deterministic equivalent of what the agent's Phase 4.6
# (`apply-pack-adaptation` skill) does for round-one. The agent has been
# routinely skipping that work; this closes the gap with a no-judgment script.
# REFINE (4.6-DEEP) still owns deepening shallow blocks — this only writes the
# round-one floor.
#
# Usage:
#   apply-anchors.sh <target-repo> [--apply]
#
# Exit codes:
#   0 — clean (dry-run by default, or --apply succeeded)
#   1 — target missing OR required extracts missing
#   2 — usage error
#   3 — blocks were injected but ZERO of the five profile facts resolved (the anchor is
#       structurally present and semantically empty). Reported, not fatal: the files are
#       written and the run continues; Phase 5 surfaces it. See the summary block.

set -euo pipefail
export LC_ALL=C

# Resolve through the global-install symlink so REPO_ROOT is the CHECKOUT, never ~/.claude.
# ~/.claude/scripts/<name> is a symlink INTO this repo, so an unresolved BASH_SOURCE makes
# dirname() report ~/.claude/scripts and every sibling asset reached for below resolves only
# if it, too, happens to have been linked. That is exactly how the merge engine went missing:
# scripts/merge-decide.py existed at HEAD, sync-to-global.sh had not been re-run since it
# landed, and $REPO_ROOT/scripts/merge-decide.py pointed at a link that was never created — so
# 238 MERGE rows across two live repos degraded to "listed, not decided" and the run still
# exited 0. See CONTRIBUTING § "Scripts run from two places". Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply]" >&2
  exit 2
fi

TARGET="$1"; shift
APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    *)       echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

PROFILE="$TARGET/.claude/codebase-profile.md"
SCAN="$TARGET/.claude/_codebase-scan.md"
IDIOMS="$TARGET/.claude/_extracted-idioms.md"   # optional — Phase 2.5 output (architecture fingerprint)

if [[ ! -f "$PROFILE" ]]; then
  echo "ERR: $PROFILE not found — Phase 2 has not run" >&2
  exit 1
fi
if [[ ! -f "$SCAN" ]]; then
  echo "ERR: $SCAN not found — Phase 0 has not run" >&2
  exit 1
fi

# Path resolution per kind — same convention as study-existing.sh
target_dir_for_kind() {
  case "$1" in
    commands)    echo "$TARGET/.claude/commands" ;;
    agents)      echo "$TARGET/.claude/agents" ;;
    skills)      echo "$TARGET/.claude/skills" ;;
    rules)       echo "$TARGET/.claude/rules" ;;
    ai-patterns) echo "$TARGET/ai/patterns" ;;
    *)           echo "$TARGET/.claude/$1" ;;
  esac
}

# Pack-derived basenames per kind
# Dual-form: flat `<kind>/<name>.md` (depth 3) AND Agent Skills dir-form
# `<kind>/<name>/SKILL.md` (depth 4). Both are reduced to the SAME identity — the
# artifact name plus `.md` — so membership below is form-independent: a target still on
# flat form still matches a pack that has moved to dir-form, and vice versa. Without the
# depth-4 branch every pack skill silently drops out of this set and anchoring skips it.
pack_basenames_for_kind() {
  local kind="$1"
  { find -L "$PACKS_ROOT" -mindepth 3 -maxdepth 3 -path "*/$kind/*.md" -not -name '_*' \
         -exec basename {} \; 2>/dev/null
    find -L "$PACKS_ROOT" -mindepth 4 -maxdepth 4 -path "*/$kind/*/SKILL.md" \
         -exec sh -c 'for p; do n=$(basename "$(dirname "$p")"); case $n in _*) ;; *) echo "$n.md" ;; esac; done' _ {} + 2>/dev/null
  } | sort -u | tr '\n' ' '
}

# Enumerate one artifact-kind dir, one line per artifact, in BOTH on-disk forms:
#   flat      <dir>/<name>.md
#   dir-form  <dir>/<name>/SKILL.md
# Emits FULL paths; callers derive the dir-relative suffix, which is the real path to the
# artifact. `_*` artifacts are dropped by the caller's existing prefix guard.
enumerate_kind_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$dir/_*" 2>/dev/null
  } | sort
}

# Canonical, form-independent artifact identity: `foo.md` and `foo/SKILL.md` both -> `foo.md`.
artifact_identity() {
  case "$1" in
    */SKILL.md) local d="${1%/SKILL.md}"; echo "${d##*/}.md" ;;
    *)          echo "${1##*/}" ;;
  esac
}

# A LIVE anchor is a `<!-- project-specific:start -->` line at column 0 that is NOT
# inside a ``` fenced code block. A marker inside a fence is DOCUMENTATION of the
# convention (a skill showing the reader what an anchor block looks like), not an
# anchor this project actually carries.
#
# This MUST agree byte-for-byte in meaning with audit-anchoring.sh's
# extract_anchor_block(), which has always skipped fenced regions. While this script
# tested only `grep -qE '^<!-- project-specific:start -->$'`, the two disagreed, and the
# disagreement was an unresolvable deadlock: a file whose ONLY marker is a fenced example
# read as "already anchored → skip" here and as an empty block ("anchor-too-thin(0-lines)")
# there — and the audit's printed remediation, "re-run apply-anchors.sh --apply", was a
# guaranteed no-op precisely because THIS branch is what skipped the file.
#
# Measured against the real 8,151-file target repo, the two files that DOCUMENT the marker
# convention deadlocked exactly this way:
#   .claude/skills/compute-anchor-density.md  (fenced example marker at SKILL.md:48)
#   .claude/skills/apply-pack-adaptation.md   (fenced example markers at SKILL.md:195,233)
# apply-anchors: "Injected 0 / Already anchored 234"; audit --strict: "2 unanchored
# (anchor-too-thin(0-lines))", REFUSED, forever.
has_live_anchor() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    /^<!-- project-specific:start -->[[:space:]]*$/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$1" 2>/dev/null
}

# ---------- Extract facts from profile/scan into one shared anchor block ----------

# Pull first non-empty content line under a "## <Heading>" section in
# codebase-profile.md, normalize to a single line. Best-effort; tolerates missing
# sections by emitting "<not declared>".
#
# BOTH heading forms are accepted — `## Architecture` AND `## 1. Architecture`.
# This used to require the numeric prefix (`/^## [0-9]+\. /`), which is NOT the form
# Phase 2 is told to write: the canonical profile shape (`templates/appendices.md`
# § Appendix D) is UNNUMBERED, and `phase-2-profile.md § Profile content` numbers the
# fields in prose only. Against a canonically-written profile the numbered-only parser
# returned nothing for all five facets, every anchor rendered five `<not declared…>`
# lines with five identical `codebase-profile.md:1` citations, and audit-anchoring.sh
# still passed it (7 substantive lines, a resolving `path:line`, and `codebase-profile.md*`
# whitelisted from its leak scan) — i.e. the deterministic auditor certified an empty
# anchor as anchored. Matching on the heading TEXT with the numeric prefix optional is
# what makes the round-one floor actually rest on extracted facts.
profile_section_first_line() {
  local heading_pattern="$1"  # e.g. "Architecture", "Naming", "Testing"
  awk -v pat="$heading_pattern" '
    function stem(h,   s) {
      s = h
      sub(/^##[[:space:]]+/, "", s)
      sub(/^[0-9]+\.[[:space:]]*/, "", s)
      return tolower(s)
    }
    BEGIN { in_section = 0; want = tolower(pat) }
    /^## / {
      if (in_section) exit
      if (index(stem($0), want) == 1) in_section = 1
      next
    }
    in_section && NF {
      gsub(/^[[:space:]]*-[[:space:]]*\*\*[^*]+\*\*[[:space:]]*:[[:space:]]*/, "")
      gsub(/^[[:space:]]*-[[:space:]]*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      print
      exit
    }
  ' "$PROFILE" 2>/dev/null
}

# Line number of a profile section, either heading form. Same optional-prefix rule as
# profile_section_first_line — the two MUST agree or a resolved fact would carry a `:1`
# citation (or vice versa).
profile_section_line() {
  # `|| true` is load-bearing under `set -o pipefail`: a profile that legitimately lacks
  # the section makes grep exit 1, which fails the whole assignment and kills the run under
  # `set -e`. A missing section must DEGRADE (fall through to `:1`), never abort — that is
  # the same degrade-never-stop discipline the extraction spec is written to.
  { grep -nE "^## ([0-9]+\.[[:space:]]*)?$1" "$PROFILE" 2>/dev/null || true; } | head -1 | cut -d: -f1
}

ARCH_LINE=$(profile_section_first_line "Architecture")
NAMING_LINE=$(profile_section_first_line "Naming")
TESTING_LINE=$(profile_section_first_line "Testing")
DATA_LINE=$(profile_section_first_line "Data access")
ERR_LINE=$(profile_section_first_line "Error handling")

# Top-level source dirs (cite-able paths) from _codebase-scan.md § "Top-level directories".
#
# HISTORY 1 — why this is not `/^src\//`. This awk filtered the scan's top-level list down to
# lines starting with `src/`, so ANY repo that does not root its code at `src/` got the
# `<none …>` placeholder shipped into every anchor it injected — even though the very file
# being read listed the real roots. Measured on a live NestJS monorepo: § 2 held `apps`,
# `apps/tenant`, `libs`, and the generator still emitted `<none>` into 27 artifacts while
# 225 older ones carried a fabricated `src/.` that does not exist in that repo. Take EVERY
# top-level entry the scan lists, then keep only the ones that resolve on disk — a citation
# the reader cannot open is worse than no citation.
#
# HISTORY 2 — why the four we keep are RANKED, not the first four alphabetically. Resolving
# on disk is necessary and nowhere near sufficient. `.husky/` resolves. `.playwright-mcp/`
# resolves. Both sort before `src/`, so on a live Vue 3 SPA whose 587 source files all live
# under `src/`, this loop took `.husky/`, `.husky/_/`, `.playwright-mcp/` and
# `new-architecture-standalone/` — 1 git-tracked file and 0 source files between them — hit
# the cap of 4, and broke out before it ever reached `src`. It then overwrote the citation
# line of 118 of 118 artifacts with that list and the run logged it as "Stale citations
# repaired: 94". The same code path on the NestJS monorepo picked `apps/`, `apps/master/`,
# `apps/tenant/` and produced a GOOD answer, which is exactly why the bug survived: it is
# layout-dependent, and alphabetical order happened to agree with source density there.
# So: collect every survivor (no early break), count the source files each one actually
# contains, and cite the four densest. A directory holding no source is not a source dir,
# whatever its name sorts as. Fixture: scripts/test-anchor-citations.sh § 1.
_CAND_FILE=$(mktemp "${TMPDIR:-/tmp}/anchor-cand.XXXXXX")
_RANK_FILE=$(mktemp "${TMPDIR:-/tmp}/anchor-rank.XXXXXX")
_GIT_TARGET=0
git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1 && _GIT_TARGET=1
while IFS= read -r _d; do
  _d="${_d%/}"
  [[ -z "$_d" ]] && continue
  case "$_d" in \#*|\>*|\|*|-*|\**) continue ;; esac
  # Setup-internal and build dirs are NOT project source. Citing `.claude/` as a "cite-able
  # source" points the reader at our own writing and makes every artifact look project-anchored
  # while naming nothing from the codebase — the smoke test that added this line watched
  # `.claude/`, `.claude/agents/` and `.claude/commands/` become the entire citation list.
  case "$_d" in
    .claude|.claude/*|ai|ai/*|.cursor|.cursor/*|.opencode|.opencode/*|.aider*|.git|.github|.vscode|.idea) continue ;;
    node_modules|dist|build|out|coverage|.next|.nuxt|.output|.svelte-kit|.turbo|vendor|tmp|logs) continue ;;
  esac
  # A TOP-LEVEL dot-directory is tooling, not source: `.husky/`, `.playwright-mcp/`,
  # `.storybook/`, `.circleci/`. Nested dot-dirs are already pruned above. This is belt to
  # the ranking's braces — the ranking alone would demote them, and this drops them outright
  # so a repo with no recognised source extension can never fall back onto one.
  case "$_d" in .*) continue ;; esac
  # A git-ignored directory is build output or local scratch by the project's OWN declaration.
  # (`.playwright-mcp/` is gitignored in the repo this rule was measured on.)
  if [[ $_GIT_TARGET -eq 1 ]] && git -C "$TARGET" check-ignore -q -- "$_d" 2>/dev/null; then continue; fi
  # Only a real directory in THIS target may be cited. This is the on-disk resolvability
  # test the leak gate could not perform, applied at the point of emission.
  [[ -d "$TARGET/$_d" ]] || continue
  printf '%s\n' "$_d" >> "$_CAND_FILE"
done < <(awk '/^## 2\.[[:space:]]*Top-level/{flag=1; next} /^## [0-9]+\./{flag=0} flag && NF && !/^#/ && !/^\x60\x60\x60/' "$SCAN" 2>/dev/null \
         | sed 's/^[[:space:]]*//; s/[[:space:]].*$//' | sort -u)
# NB: NO `head` on that stream, and no `break` in that loop. The truncation must happen AFTER
# the exclusions AND after the ranking, never before. The scan lists dirs alphabetically, so
# `.claude`, `.claude/agents`, `.claude/commands`, `.claude/hooks`, `.claude/rules`,
# `.claude/skills` occupy the first SIX rows of a typical target — a pre-filter `head -6`
# handed this loop nothing but setup-internal dirs, every one of which the exclusion then
# dropped, leaving the `<none>` placeholder on a repo whose real roots (`apps/`, `libs/`) were
# three lines further down. Caught by an end-to-end smoke test, not by reading the diff.

# ONE walk of the tree, then attribute every file to each candidate that prefixes it. Two
# tallies per candidate: files carrying a source extension, and files of any kind. Source
# density decides; total files is the tiebreak and the fallback for a stack whose extensions
# this list does not know (better a real directory than the `<none>` placeholder).
if [[ -s "$_CAND_FILE" ]]; then
  find "$TARGET" \
       -type d \( -name node_modules -o -name .git -o -name dist -o -name build \
                  -o -name .next -o -name .nuxt -o -name .output -o -name .svelte-kit \
                  -o -name .turbo -o -name vendor -o -name __pycache__ -o -name .venv \
                  -o -name coverage \) -prune -o -type f -print 2>/dev/null \
  | awk -v tgt="$TARGET/" -v candfile="$_CAND_FILE" '
      BEGIN {
        split("ts tsx js jsx mjs cjs vue svelte py rb go rs java kt kts scala clj ex exs \
               php cs swift m mm c cc cpp h hpp hxx sql prisma graphql gql proto \
               css scss sass less styl html htm erb haml blade twig tpl sh bash zsh", _e, /[ \t\n]+/)
        for (i in _e) if (_e[i] != "") SRC[_e[i]] = 1
        n = 0
        while ((getline c < candfile) > 0) if (c != "") { cand[++n] = c; src[c] = 0; tot[c] = 0 }
      }
      {
        p = $0
        if (index(p, tgt) != 1) next
        p = substr(p, length(tgt) + 1)
        ext = ""
        if (match(p, /\.[A-Za-z0-9]+$/)) ext = tolower(substr(p, RSTART + 1))
        for (i = 1; i <= n; i++) {
          c = cand[i]
          if (index(p, c "/") == 1) { tot[c]++; if (ext in SRC) src[c]++ }
        }
      }
      END { for (i = 1; i <= n; i++) { c = cand[i]; printf "%d\t%d\t%s\n", src[c], tot[c], c } }
    ' > "$_RANK_FILE" 2>/dev/null || true
fi
SRC_DIRS=""
_srcn=0
# BREADTH BEFORE DEPTH — one slot per distinct top-level ROOT first, then fill.
#
# The cap is 4 and the candidate list contains nested dirs, so on the reference monorepo the ranking
# spent three of the four slots inside ONE tree (`apps/`, `apps/tenant/`, `apps/master/`) plus
# `chrome-extension/`, and `libs/` — the shared-library root that half that codebase lives in —
# was cut. The same anchor block cites `DataAccess<…> at libs/database/src/repository/
# data-access.ts` three lines above, so the block was telling a reader to cite from a directory
# it had just declined to list as cite-able. Every path it printed resolved, so no gate saw it.
# Pass 1 takes the best candidate from each distinct first segment; pass 2 spends whatever is
# left on the next-best candidates of any depth. Ranking is unchanged; only the ORDER of
# spending is.
_seen_roots=""
for _pass in 1 2; do
  while IFS=$'\t' read -r _sc _tc _d; do
    [[ -z "${_d:-}" ]] && continue
    # A candidate with nothing in it at all is never cited. A candidate with files but no
    # recognised source extension is cited only in the fallback pass below.
    [[ "${_sc:-0}" -gt 0 ]] || continue
    _root="${_d%%/*}"
    if [[ "$_pass" -eq 1 ]]; then
      case " $_seen_roots " in *" $_root "*) continue ;; esac
    else
      case ", $SRC_DIRS," in *"\`$_d/\`,"*) continue ;; esac
      [[ "$SRC_DIRS" == "\`$_d/\`"* ]] && continue
    fi
    [[ -n "$SRC_DIRS" ]] && SRC_DIRS="$SRC_DIRS, "
    SRC_DIRS="$SRC_DIRS\`$_d/\`"
    _seen_roots="$_seen_roots $_root"
    _srcn=$(( _srcn + 1 ))
    [[ "$_srcn" -ge 4 ]] && break
  done < <(sort -t$'\t' -k1,1nr -k2,2nr -k3,3 "$_RANK_FILE" 2>/dev/null || true)
  [[ "$_srcn" -ge 4 ]] && break
done
if [[ -z "$SRC_DIRS" ]]; then
  while IFS=$'\t' read -r _sc _tc _d; do
    [[ -z "${_d:-}" ]] && continue
    [[ "${_tc:-0}" -gt 0 ]] || continue
    [[ -n "$SRC_DIRS" ]] && SRC_DIRS="$SRC_DIRS, "
    SRC_DIRS="$SRC_DIRS\`$_d/\`"
    _srcn=$(( _srcn + 1 ))
    [[ "$_srcn" -ge 4 ]] && break
  done < <(sort -t$'\t' -k2,2nr -k3,3 "$_RANK_FILE" 2>/dev/null || true)
fi
rm -f "$_CAND_FILE" "$_RANK_FILE"
# Nothing resolved is a real answer — but it must NOT be dressed up as a citation. Emit the
# honest no-citation form; audit-anchoring.sh § TOPLEVEL_RE treats a `<…>` value as a
# placeholder and fails the block under --strict rather than passing it as a clean anchor.
[[ -z "$SRC_DIRS" ]] && SRC_DIRS="<none — no top-level source dir resolved on disk>"

# Manifests we know exist (cite-able)
MANIFESTS=""
for m in package.json tsconfig.json vite.config.ts next.config.js pyproject.toml pom.xml go.mod Gemfile composer.json Cargo.toml; do
  if [[ -f "$TARGET/$m" ]]; then
    [[ -n "$MANIFESTS" ]] && MANIFESTS="$MANIFESTS, "
    MANIFESTS+="\`$m\`"
  fi
done
[[ -z "$MANIFESTS" ]] && MANIFESTS="(none detected)"

# Per-section line numbers in the profile — gives every injected block at least
# one verifiable `path:line` citation, which is what audit-anchoring.sh looks for.
arch_ln=$(profile_section_line "Architecture")
naming_ln=$(profile_section_line "Naming")
testing_ln=$(profile_section_line "Testing")
data_ln=$(profile_section_line "Data access")
err_ln=$(profile_section_line "Error handling")

# How many of the five facets actually resolved. An anchor built from zero resolved
# facts is five `<not declared…>` lines wearing a citation costume — it satisfies every
# downstream presence check while telling the reader nothing about this project. Count
# it here so the shortfall is REPORTED rather than silently shipped (see the summary
# block and exit code 3 below).
facts_resolved=0
facts_missing=""
for pair in "Architecture:$ARCH_LINE" "Naming:$NAMING_LINE" "Testing:$TESTING_LINE" \
            "Data access:$DATA_LINE" "Error handling:$ERR_LINE"; do
  if [[ -n "${pair#*:}" ]]; then
    facts_resolved=$((facts_resolved + 1))
  else
    facts_missing+="${facts_missing:+, }${pair%%:*}"
  fi
done

# Architecture fingerprint — when Phase 2.5 ran and produced _extracted-idioms.md,
# pull the base-class H1 list (top 5) so every anchor block names this project's
# actual load-bearing classes instead of just generic "Architecture: layered".
# This is what makes the anchor architecture-aware vs template-shaped.
BASE_CLASSES=""
if [[ -f "$IDIOMS" ]]; then
  # TWO on-disk shapes, both real, so read both:
  #   (a) the `_extracted-idioms.md` schema in `phase-2-profile.md § Output schema` —
  #       ONE H1 (`# Project idioms — <project>`) plus H2 sections per idiom kind,
  #       each holding `- <Name> (<path>) — <role> — <n> <dependents>` rows;
  #   (b) the per-base pattern shape `# <BaseName><Generics> Pattern` that
  #       `extract-base-class-idiom § Step 6` authors when it appends per base.
  # Reading only (b)'s `^# ` — which is what this did — turns shape (a)'s single title
  # line into a fake "base class" named `Project idioms — <project>`, and misses every
  # composable / wrapper / shared service / type primitive the file actually names.
  # Shape (a) rows are the ones a non-class project has at all.
  BASE_CLASSES=$({
    awk '
      /^## (Wrappers|Composables|Shared services|Base classes|Type primitives)/ { in_sec = 1; next }
      /^## / { in_sec = 0 }
      in_sec && /^-[[:space:]]/ {
        line = $0
        sub(/^-[[:space:]]*/, "", line)
        sub(/[[:space:]]*[(—-].*$/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "" && line !~ /^</) print line
      }
    ' "$IDIOMS" 2>/dev/null
    { grep -E '^# .* Pattern$' "$IDIOMS" 2>/dev/null || true; } \
      | sed -E 's/^# +//; s/ +Pattern$//'
  } | awk 'NF && !seen[$0]++' \
    | head -5 \
    | awk 'NF { printf "%s`%s`", (NR>1 ? ", " : ""), $0 } END { print "" }')
fi


# --- PER-ARTIFACT relevance (the half of an anchor that is not a global constant) ----------
#
# HISTORY — every anchor this script wrote was the SAME five profile facts, so "project-aware"
# meant "carries a copy of one global block". Measured on a live repo: 255 anchored artifacts
# shared just SIX distinct anchor bodies — 137 byte-identical, 88 byte-identical, 27
# byte-identical — and a caching-architect agent, a saga command, a DLQ-replay skill and a
# backpressure pattern all carried identical text. Resolving every path token in five newly
# installed artifacts found exactly ONE project source file referenced by any of them, and it
# came from the shared block. The audit reported "Coverage: 100% — All pack-derived artifacts
# are anchored with real project facts": the facts were real, they just were not ABOUT the
# artifact.
#
# This adds one line that can only be computed per artifact: does this artifact's own subject
# appear in this codebase, and where? It is also the honest answer to the other half of the
# complaint — a saga command whose own body says "saga runtime unconfirmed … halt" installed
# anyway now says so on its first line, with the grep that proves it.

# Distinctive terms for an artifact: from its frontmatter `name`, plus the longest words of its
# `description`, minus a stoplist of words that appear in every artifact.
# The artifact's NAME is its subject; the description is prose and full of ordinary English.
# HISTORY: this read name AND description together and scored by hit count, so the winning
# "distinctive term" for an agent came out as `already` and `against` — words that appear
# everywhere and mean nothing. Name tokens first (`caching-architect` -> caching, architect),
# and only fall back to long description words when no name token resolves.
artifact_terms() {
  local f="$1" want="${2:-name}"
  awk -v w="$want" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} $0 ~ "^"w":"{print}' "$f" 2>/dev/null \
    | sed -E 's/^(name|description):[[:space:]]*//' \
    | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' '\n' \
    | awk -v w="$want" '(w=="name" && length($0) >= 4) || (w=="description" && length($0) >= 8)' \
    | grep -vwE 'about|above|after|again|against|agent|alone|along|already|also|always|among|another|apply|around|audit|based|because|before|being|below|between|both|build|cannot|check|claude|clean|codebase|command|could|create|does|done|during|each|either|else|enough|even|every|exist|files|first|found|framework|from|generate|given|guide|have|helper|here|however|inside|instead|into|itself|junior|just|kind|less|like|list|made|makes|many|more|most|much|must|name|need|never|next|nothing|once|only|other|output|over|pattern|point|project|rather|repository|report|review|rules|running|same|scope|senior|shape|shipped|should|since|skill|some|source|steps|still|style|such|surface|take|target|than|that|their|them|then|there|these|they|thing|this|those|three|through|toolchain|track|under|until|update|upon|used|uses|using|value|very|what|when|where|which|while|whole|will|with|within|without|would|write|writes|written|your' \
    | sort -u | head -6
}

# Search the target's SOURCE (not .claude/, not ai/ — those are our own writing) for a term.
# Sets TERM_EVIDENCE ("path:line" or "") and TERM_HITS (file count).
#
# NB: globals, not an echoed value. A `$( )` call runs in a subshell, so a TERM_HITS assigned
# inside one is discarded the moment it returns — the caller then compares 0 > 0 forever and
# EVERY artifact reports "Relevance UNCONFIRMED" even when its subject is right there in the
# codebase. That is exactly what the first draft of this function did.
TERM_HITS=0
TERM_EVIDENCE=""
term_evidence() {
  local term="$1" hit
  TERM_HITS=0
  TERM_EVIDENCE=""
  [[ ${#SEARCH_DIRS[@]} -eq 0 ]] && return 0
  hit=$(grep -rInI --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor \
        --exclude-dir=dist --exclude-dir=build --exclude-dir=.claude --exclude-dir=ai \
        -m1 -- "$term" "${SEARCH_DIRS[@]}" 2>/dev/null | head -1 || true)
  [[ -z "$hit" ]] && return 0
  TERM_HITS=$(grep -rlI --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor \
        --exclude-dir=dist --exclude-dir=build --exclude-dir=.claude --exclude-dir=ai \
        -- "$term" "${SEARCH_DIRS[@]}" 2>/dev/null | grep -c . || true)
  TERM_HITS="${TERM_HITS:-0}"
  # `grep -rIn` prints path:line:text — keep path:line (target-relative), drop the text.
  local pth="${hit%%:*}"
  TERM_EVIDENCE="${pth#$TARGET/}:$(printf '%s' "$hit" | cut -d: -f2)"
  return 0
}

# Where to look for artifact subject matter: the real top-level source dirs this run resolved.
SEARCH_DIRS=()
while IFS= read -r d; do
  d="$(printf '%s' "$d" | tr -d '`' | sed 's|/*$||')"
  [[ -n "$d" && -d "$TARGET/$d" ]] && SEARCH_DIRS+=("$TARGET/$d")
done < <(printf '%s\n' "$SRC_DIRS" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^<')
[[ ${#SEARCH_DIRS[@]} -eq 0 ]] && SEARCH_DIRS=("$TARGET")

# The per-artifact line. Always emitted, always true, and never the same for two artifacts
# whose subjects differ.
artifact_relevance_line() {
  local f="$1" term best_term="" best_ev="" best_hits=0 tried=""
  for _src in name description; do
    while IFS= read -r term; do
      [[ -z "$term" ]] && continue
      tried="$tried${tried:+, }\`$term\`"
      term_evidence "$term"
      if [[ -n "$TERM_EVIDENCE" && "$TERM_HITS" -gt "$best_hits" ]]; then
        best_hits="$TERM_HITS"; best_term="$term"; best_ev="$TERM_EVIDENCE"
      fi
    done < <(artifact_terms "$f" "$_src")
    [[ -n "$best_term" ]] && break     # a name-token hit beats any description word
  done

  if [[ -n "$best_term" ]]; then
    printf '> - **Where this applies here** (`%s`): `%s`, %d file(s) in %s' \
      "$best_term" "$best_ev" "$best_hits" "$(printf '%s' "${SEARCH_DIRS[*]#$TARGET/}" | tr ' ' ',')"
  elif [[ -n "$tried" ]]; then
    printf '> - **Relevance UNCONFIRMED**: none of %s occurs in this codebase. Treat this artifact as generic guidance and verify its preconditions before acting on it.' "$tried"
  else
    printf '> - **Relevance UNCONFIRMED**: this artifact declares no distinctive subject terms to search for.'
  fi
}

# Compose anchor block — uniform across artifacts except optional TBD token count.
# Round-one floor; REFINE specializes per-artifact based on `compute-anchor-density`
# scoring. When _extracted-idioms.md is present, append an extra "Detected base classes"
# line so the anchor names the project's real architecture, not just five
# generic facets.
# $1 = optional count of <TBD:...> placeholders in the target file body (Phase 4.6 contract).
build_block() {
  local tbd_count="${1:-0}"
  local relevance="${2:-}"
  local idiom_line=""
  if [[ -n "$BASE_CLASSES" ]]; then
    idiom_line="> - **Detected load-bearing idioms** (\`_extracted-idioms.md\`): ${BASE_CLASSES}"$'\n'">"
  fi
  local tbd_line=""
  if [[ "${tbd_count}" -gt 0 ]]; then
    tbd_line=$'\n''> - **Stack placeholders pending**: '"${tbd_count}"' `<TBD:...>` token(s) in this file — Phase 4.6-DEEP / REFINE substitutes from `_extracted-codebase.md` / `_extracted-idioms.md`.'
  fi
  cat <<BLOCK
<!-- project-specific:start -->
## Project-specific (auto-generated, regenerate with \`/setup-project --refine\`)

> Auto-populated by \`scripts/apply-anchors.sh\` from \`.claude/codebase-profile.md\` + \`.claude/_codebase-scan.md\`$([[ -n "$BASE_CLASSES" ]] && echo " + \`.claude/_extracted-idioms.md\`"). Round-one floor — \`/setup-project --refine\` deepens shallow blocks based on \`compute-anchor-density\` scoring.
>
> - **Architecture** (\`.claude/codebase-profile.md:${arch_ln:-1}\`): ${ARCH_LINE:-<not declared in codebase-profile.md>}
> - **Naming** (\`.claude/codebase-profile.md:${naming_ln:-1}\`): ${NAMING_LINE:-<not declared in codebase-profile.md>}
> - **Testing** (\`.claude/codebase-profile.md:${testing_ln:-1}\`): ${TESTING_LINE:-<not declared in codebase-profile.md>}
> - **Data access** (\`.claude/codebase-profile.md:${data_ln:-1}\`): ${DATA_LINE:-<not declared in codebase-profile.md>}
> - **Error handling** (\`.claude/codebase-profile.md:${err_ln:-1}\`): ${ERR_LINE:-<not declared in codebase-profile.md>}
${idiom_line}${tbd_line}
${relevance}
> Cite-able sources: ${MANIFESTS}, top-level: ${SRC_DIRS}.

<!-- project-specific:end -->

BLOCK
}


# --- Stale-anchor repair (migration for content this script already shipped) --------
#
# An anchor block's `Cite-able sources: …, top-level: <value>` tail is the only path this
# script emits UNBACKTICKED, and for a long time its value was hard-coded to `src/`. Every
# artifact anchored by that build carries a directory that may not exist in the target, and
# because those artifacts are "already anchored" no later run ever looked at them again.
# These two helpers make the skip conditional: detect a top-level citation that no longer
# resolves, and rewrite that ONE line to the value the current run computed.

# 0 = the file's anchor block cites a top-level dir that does not resolve in $TARGET
#     (or cites a <placeholder> instead of a path). 1 = its citation is fine / absent.
anchor_toplevel_is_stale() {
  local f="$1" line val d
  line=$(grep -m1 -E '^>[[:space:]]*Cite-able sources:' "$f" 2>/dev/null || true)
  # NO citation line at all, inside a file that HAS an anchor, is the worst of the three states
  # and used to be the one that returned "fine". MEASURED: after a skill-shape migration,
  # .claude/skills/composite-surface-check/SKILL.md was the single artifact in its repo carrying
  # an anchor block and no `Cite-able sources:` line — 119 artifacts had an anchor end tag, 118
  # had a citation — and no later run ever looked at it again, because "already anchored" plus
  # "citation absent → not stale" is a permanent skip. An anchor with no citation is stale.
  if [[ -z "$line" ]]; then
    grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$f" 2>/dev/null && return 0
    return 1
  fi
  val="${line#*top-level:}"
  [[ "$val" == "$line" ]] && return 1          # no top-level clause at all
  val="${val%.}"
  # A <placeholder> value is stale whenever the current run DID resolve real dirs.
  case "$val" in
    *"<"*) [[ "$SRC_DIRS" == "<"* ]] && return 1; return 0 ;;
  esac
  # Otherwise: every cited entry must resolve as a directory under the target.
  #
  # Split on WHITESPACE as well as commas. This script emits the comma form, but the form it
  # emitted before that was space-separated (`top-level: src/assets src/components
  # src/composables.`), and splitting on commas alone turned those three real directories into
  # one 43-character token that resolves as nothing — so every artifact carrying the older
  # form was declared stale and overwritten. On the run that exposed this, that verdict was
  # wrong for all 118 artifacts in the target and the replacement value was worse than what it
  # replaced. A citation whose parts all resolve is NOT stale, whichever separator wrote it.
  # Fixture: scripts/test-anchor-citations.sh § 2.
  while IFS= read -r d; do
    d="${d%/}"
    [[ -z "$d" ]] && continue
    [[ -d "$TARGET/$d" ]] || return 0
  done < <(printf '%s\n' "$val" | tr ',[:space:]' '\n\n' | tr -d '`' \
           | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$')
  return 1
}

# ---- anchor UNIQUENESS: the per-artifact line, retro-fitted -----------------------------
#
# THE DEFECT. Anchoring coverage reads 100% and says almost nothing. MEASURED: the reference monorepo
# 195 anchored artifacts / 20 distinct anchor bodies / largest identical group 110 (56%);
# the sibling repo 88 / 11 / 57 (65%). The target's own report already names it — "Distinct anchor
# bodies: 16 of 106 anchored (15%) … a global constant wearing a citation costume" — while
# audit-setup.sh C2d printed "ok anchoring coverage 100%" in the same run.
#
# THE CAUSE IS A MISSING MIGRATION, not a missing idea. `artifact_relevance_line` already
# produces a line that differs for every artifact whose subject differs, and every block this
# script INJECTS carries one. But an artifact anchored by an EARLIER release is "already
# anchored", so it is skipped forever and keeps the generator's old, identical body — the exact
# shape of the `src/.` citation defect one function above, which was fixed the same way.
#
# So: one line, added in place, to a block that has none. Everything else in the block —
# including hand-written depth under the anchor — is left byte-for-byte alone.
# Fixture: scripts/test-anchor-citations.sh § 9.
anchor_lacks_relevance() {
  local f="$1"
  awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { inb=1; next }
    inb && /^<!-- project-specific:end -->[[:space:]]*$/ { inb=0 }
    inb && (/^>[[:space:]]*-[[:space:]]*\*\*Where this applies here\*\*/ ||
            /^>[[:space:]]*-[[:space:]]*\*\*Relevance UNCONFIRMED\*\*/) { found=1 }
    END { exit found ? 1 : 0 }
  ' "$f" 2>/dev/null
}

# Insert the relevance line immediately BEFORE the Cite-able-sources line (the block's last
# content line), or immediately before the end marker when there is no citation line yet.
insert_relevance_line() {
  local f="$1" line="$2" tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/anchor-relev.XXXXXX")
  REL_LINE="$line" awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { inb=1; print; next }
    inb && !done && /^>[[:space:]]*Cite-able sources:/ { print ENVIRON["REL_LINE"]; done=1; print; next }
    inb && !done && /^<!-- project-specific:end -->[[:space:]]*$/ { print ENVIRON["REL_LINE"]; done=1; inb=0; print; next }
    inb && /^<!-- project-specific:end -->[[:space:]]*$/ { inb=0 }
    { print }
  ' "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

# Rewrite the Cite-able-sources line in place from the values this run computed.
# Only that line changes; the rest of the block (including hand-added depth) is untouched.
repair_citeable_line() {
  local f="$1" tmp
  tmp=$(mktemp "${TMPDIR:-/tmp}/anchor-repair.XXXXXX")
  # Two modes, because the line may be WRONG or may be MISSING. Rewriting handles the first;
  # the second needs an insert, immediately after the anchor's start marker, or the artifact
  # keeps its anchor and never gains a citation (see anchor_toplevel_is_stale's [[ -z ]] arm).
  if grep -qE '^>[[:space:]]*Cite-able sources:' "$f" 2>/dev/null; then
    MANIFESTS="$MANIFESTS" SRC_DIRS="$SRC_DIRS" awk '
      /^>[[:space:]]*Cite-able sources:/ && !done {
        printf "> Cite-able sources: %s, top-level: %s.\n", ENVIRON["MANIFESTS"], ENVIRON["SRC_DIRS"]
        done = 1
        next
      }
      { print }
    ' "$f" > "$tmp" && cat "$tmp" > "$f"
  else
    MANIFESTS="$MANIFESTS" SRC_DIRS="$SRC_DIRS" awk '
      { print }
      /^<!-- project-specific:start -->[[:space:]]*$/ && !done {
        printf "> Cite-able sources: %s, top-level: %s.\n", ENVIRON["MANIFESTS"], ENVIRON["SRC_DIRS"]
        done = 1
      }
    ' "$f" > "$tmp" && cat "$tmp" > "$f"
  fi
  rm -f "$tmp"
}

# ---------- Inject into eligible artifacts ----------

# Find insertion point in a file: after frontmatter (if any), after the first H1
# (if any), before the first H2 (if any). If none of those exist, prepend.
# Returns the line number AFTER which to insert (1-based; 0 = prepend).
find_insertion_line() {
  local f="$1"
  awk '
    BEGIN { state="start"; fm_end=0; h1=0; h2=0 }
    NR == 1 && /^---[[:space:]]*$/ { state="fm"; next }
    state == "fm" && /^---[[:space:]]*$/ { fm_end=NR; state="body"; next }
    state == "body" && /^# / && !h1 { h1=NR; next }
    state == "body" && /^## / && !h2 { h2=NR; exit }
    state == "start" && /^# / && !h1 { h1=NR; state="body"; next }
    state == "start" && /^## / && !h2 { h2=NR; exit }
    END {
      if (h2 > 0) print h2 - 1
      else if (h1 > 0) print h1
      else if (fm_end > 0) print fm_end
      else print 0
    }
  ' "$f"
}

inject_block() {
  local f="$1"
  local insert_after="$2"
  local block="$3"
  local tmp
  tmp=$(mktemp)
  # THE BLANK LINE GOES AFTER THE BLOCK, NOT BEFORE IT — and this one line is why the whole
  # programme's headline metric could not move off zero.
  #
  # Every reader of a deployed artifact strips the anchor to recover "the pack-derived
  # content": study-existing.sh stripped_target(), merge-decide.py split_anchors(). Both drop
  # the single blank line that FOLLOWS the `:end -->` marker, because that is the shape
  # compose_override() writes. This function wrote the blank BEFORE the `:start -->` marker
  # and none after, so the strip left one extra blank line in every single artifact and NO
  # anchored file could ever compare equal to its pack source. MEASURED across two live repos:
  # byte-for-byte currency 0 → 0 over 207 pack commands+agents after 154 files were rewritten
  # from current pack source — `.claude/agents/websocket-engineer.md` stripped was 190 lines
  # against a 189-line pack and the complete unified diff was `@@ -9,0 +10 @@` / `+`. A fully
  # successful run reported as total failure.
  #
  # The leading blank is emitted only when the preceding line is not already blank, because
  # find_insertion_line() returns `h2 - 1` and that line is usually — not always — the pack's
  # own separator. Fixture: scripts/test-anchor-citations.sh § 8.
  if [[ "$insert_after" -eq 0 ]]; then
    {
      printf '%s\n\n' "$block"
      cat "$f"
    } > "$tmp"
  else
    {
      head -n "$insert_after" "$f"
      local prev
      prev="$(sed -n "${insert_after}p" "$f")"
      [[ -n "${prev//[[:space:]]/}" ]] && printf '\n'
      printf '%s\n\n' "$block"
      tail -n +$((insert_after + 1)) "$f"
    } > "$tmp"
  fi
  mv "$tmp" "$f"
}

# Safety-net: scrub leftover upstream "Project-specific block" instructional
# blockquotes that contain `<extracted-from-codebase>` placeholders. These
# blockquotes are obsolete (replaced by the canonical marker block this script
# injects); some pack source files still ship them and they survive into the
# downstream project as confusing stale prose. We only scrub blockquotes that
# both reference Phase 4.6 AND contain a placeholder line — never user content.
scrub_upstream_placeholder_blockquote() {
  local f="$1"
  grep -qF '<extracted-from-codebase>' "$f" 2>/dev/null || return 0
  grep -qE '^>[[:space:]]*\*\*Project-specific block\*\*' "$f" 2>/dev/null || return 0

  local tmp
  tmp=$(mktemp)
  awk '
    BEGIN { in_blockquote=0; saw_marker=0 }
    /^>[[:space:]]*\*\*Project-specific block\*\*.*Phase 4\.6/ {
      in_blockquote=1; saw_marker=1; next
    }
    in_blockquote && /^>/ { next }
    in_blockquote && !/^>/ { in_blockquote=0 }
    { print }
    END { exit (saw_marker ? 0 : 0) }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

ts=$(date +%Y%m%d-%H%M%S)
backup_dir="$TARGET/.claude/backups/anchors-$ts"

injected=0
already=0
repaired=0
relev=0
orphans=0
processed=0

echo "=== apply-anchors ==="
echo "Target:  $TARGET"
echo "Mode:    $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Profile: $PROFILE"
echo "Scan:    $SCAN"
if [[ -f "$IDIOMS" ]]; then
  echo "Idioms:  $IDIOMS  (architecture fingerprint — anchors will name detected load-bearing idioms)"
else
  echo "Idioms:  (absent — anchors will be 5-facet only; Phase 2.5 was skipped or had no signal)"
fi
echo ""

for kind in commands agents skills rules ai-patterns; do
  tgt_dir=$(target_dir_for_kind "$kind")
  [[ -d "$tgt_dir" ]] || continue
  pack_bases=$(pack_basenames_for_kind "$kind")

  while IFS= read -r f; do
    base="${f#"$tgt_dir"/}"
    [[ "$base" == _* ]] && continue
    processed=$((processed + 1))

    # Pack-derived? (compared on the form-independent identity, so a dir-form
    # `<name>/SKILL.md` target matches the pack's `<name>.md` identity key)
    if [[ " $pack_bases " != *" $(artifact_identity "$base") "* ]]; then
      orphans=$((orphans + 1))
      continue
    fi

    # Already anchored?
    # Two ways a marker can appear without being a live anchor, both of which must NOT
    # count as anchored:
    #   1. inline in prose / backticks — "the `<!-- project-specific:start -->` block"
    #      (excluded by the `^...$` anchors inside has_live_anchor)
    #   2. at column 0 but inside a ``` fence — a worked example in a file that TEACHES
    #      the marker convention (excluded by has_live_anchor's fence tracking)
    # See has_live_anchor above for the deadlock this second case used to cause.
    #
    # An already-anchored file is NOT unconditionally skipped any more. HISTORY: the
    # `top-level:` half of the Cite-able-sources line used to be hard-coded to `src/`, so
    # every artifact anchored by an older build of this script carries a directory that may
    # not exist in the target. Measured on a live NestJS monorepo: 225 of 254 anchored
    # artifacts cited `src/.` and there is no `src/` there. Because those files were already
    # anchored, every subsequent run skipped them and the fabrication was permanent — the
    # generator was fixed with NO migration for the content it had already shipped. So:
    # when the block's own top-level citation no longer resolves on disk, repair that ONE
    # line in place. Everything else in the block — including any hand-written depth a
    # human added under the anchor — is left byte-for-byte alone.
    if has_live_anchor "$f"; then
      touched_this_file=0
      if anchor_toplevel_is_stale "$f"; then
        if [[ "$APPLY" -eq 1 ]]; then
          mkdir -p "$backup_dir"
          rel="${f#$TARGET/}"
          bak="$backup_dir/$rel"
          mkdir -p "$(dirname "$bak")"
          [[ -f "$bak" ]] || { mkdir -p "$(dirname "$bak")"; cp "$f" "$bak"; }
          repair_citeable_line "$f"
          echo "  REPAIR  $rel  (stale top-level citation refreshed)"
        else
          echo "  would-REPAIR $kind/$base  (stale top-level citation)"
        fi
        repaired=$((repaired + 1))
        touched_this_file=1
      fi
      # The uniqueness migration. An anchor written by an earlier release carries no
      # per-artifact line, so it is byte-identical to every other block that release wrote —
      # and "already anchored" meant it could never be improved. Add the one line that makes
      # the block about THIS artifact; touch nothing else.
      if anchor_lacks_relevance "$f"; then
        if [[ "$APPLY" -eq 1 ]]; then
          mkdir -p "$backup_dir"
          rel="${f#$TARGET/}"
          bak="$backup_dir/$rel"
          mkdir -p "$(dirname "$bak")"
          [[ -f "$bak" ]] || cp "$f" "$bak"
          insert_relevance_line "$f" "$(artifact_relevance_line "$f")"
          echo "  RELEV   $rel  (per-artifact relevance line added to an existing anchor)"
        else
          echo "  would-RELEV $kind/$base  (anchor has no per-artifact relevance line)"
        fi
        relev=$((relev + 1))
        touched_this_file=1
      fi
      [[ "$touched_this_file" -eq 0 ]] && already=$((already + 1))
      continue
    fi

    insert_line=$(find_insertion_line "$f")

    if [[ "$APPLY" -eq 1 ]]; then
      # Backup
      mkdir -p "$backup_dir"
      rel="${f#$TARGET/}"
      bak="$backup_dir/$rel"
      mkdir -p "$(dirname "$bak")"
      cp "$f" "$bak"

      tbd_count=$({ grep -oE '<TBD:[^>]+>' "$f" 2>/dev/null || true; } | wc -l | tr -d ' ')
      ANCHOR_BLOCK=$(build_block "${tbd_count:-0}" "$(artifact_relevance_line "$f")")
      inject_block "$f" "$insert_line" "$ANCHOR_BLOCK"
      scrub_upstream_placeholder_blockquote "$f"
      echo "  INJECT  $rel  (after line $insert_line)"
    else
      echo "  would-INJECT $kind/$base  (after line $insert_line)"
    fi
    injected=$((injected + 1))
  done < <(enumerate_kind_dir "$tgt_dir")
done

echo ""
echo "=== summary ==="
echo "Processed:                     $processed"
echo "Injected (or would-inject):    $injected"
echo "Already anchored (skipped):    $already"
echo "Stale citations repaired:      $repaired"
echo "Relevance lines retro-fitted:  $relev"
echo "Orphans (project-only):        $orphans"
echo "Profile facts resolved:        $facts_resolved/5"
if [[ -n "$facts_missing" ]]; then
  echo ""
  echo "WARN: $((5 - facts_resolved)) of 5 anchor facts did not resolve: $facts_missing"
  echo "      Every injected block renders those as \`<not declared in codebase-profile.md>\`."
  echo "      Expected headings in $PROFILE (either \`## Naming\` or \`## 3. Naming\` form):"
  echo "        ## Architecture / ## Naming / ## Testing / ## Data access / ## Error handling"
  echo "      Shape reference: templates/appendices.md § Appendix D."
fi
if [[ "$APPLY" -eq 1 && "$injected" -gt 0 ]]; then
  echo "Backups:                       $backup_dir/"
fi
[[ "$APPLY" -eq 0 ]] && echo "Dry run — pass --apply to execute."

# Exit 3 — the anchor was written, and it is empty. NOT exit 1: the injection itself
# succeeded and the run should continue; this is a REPORTED shortfall, which is the whole
# difference between "anchored" meaning something and meaning nothing. Reserved for the
# unambiguous case — ZERO of five facets resolved, i.e. a block whose every content line is
# `<not declared in codebase-profile.md>` and whose five citations all point at line 1.
# A partial shortfall (1-4 resolved) warns above and still exits 0.
if [[ "$facts_resolved" -eq 0 && "$injected" -gt 0 ]]; then
  echo ""
  echo "ERR: anchor blocks were built from ZERO resolved profile facts — the round-one floor"
  echo "     is five \`<not declared…>\` lines. Fix $PROFILE (Phase 2) and re-run."
  exit 3
fi
exit 0

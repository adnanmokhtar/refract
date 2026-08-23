#!/usr/bin/env bash
# test-anchor-citations.sh — fixture suite for the ONE line apply-anchors.sh writes into every
# artifact it touches: `> Cite-able sources: <manifests>, top-level: <dirs>.`
#
# WHY THIS SUITE EXISTS. That line is the only project-specific fact most artifacts carry, and
# it is written unconditionally over whatever was there before. On a live Vue 3 SPA the picker
# cited `.husky/`, `.husky/_/`, `.playwright-mcp/` and `new-architecture-standalone/` — between
# them 1 git-tracked file and 0 source files — into 118 of 118 artifacts, replacing
# `src/assets src/components src/composables`, and the run logged the overwrite as "Stale
# citations repaired: 94". The identical code path on a NestJS monorepo picked `apps/`,
# `apps/master/`, `apps/tenant/` and looked correct, which is why the defect survived every
# copy-based test: it is LAYOUT-dependent. Alphabetical order agreed with source density in one
# repo and disagreed in the other.
#
# Two independent failures had to line up, so this suite pins both:
#   § 1  the picker took the first four survivors in ALPHABETICAL order and broke at the cap,
#        so a dot-directory that sorts early beat the source tree that sorts late.
#   § 2  the staleness test split the existing citation on commas only, so the older
#        space-separated form read as one unresolvable token — every artifact carrying it was
#        declared stale and overwritten with the bad value from § 1.
#   § 3  the monorepo layout that looked fine must STILL look fine (no-regression).
#   § 4  a citation that genuinely does not resolve must still be repaired — the fix must not
#        buy safety by turning the repair off.
#
# Everything runs under mktemp -d. Nothing is written outside it.
#
# Usage: test-anchor-citations.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
ANCHORS="$REPO_ROOT/scripts/apply-anchors.sh"
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

[ -f "$ANCHORS" ] || { echo "ERR: $ANCHORS not found" >&2; exit 1; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-anchor-citations.XXXXXX")
trap 'rm -rf "$TD"' EXIT

# ---- helpers ---------------------------------------------------------------------------
# Write the two Phase-0/Phase-2 inputs apply-anchors.sh requires. $2.. = the § 2 dir list.
seed_setup() {
  local root="$1"; shift
  mkdir -p "$root/.claude/commands"
  {
    printf '# Codebase scan\n\n## 1. Size\n\n## 2. Top-level directories (depth 2)\n\n```\n'
    printf '%s\n' "$@"
    printf '```\n\n## 3. Manifests + framework markers\n\n```\npackage.json  package.json\n```\n'
  } > "$root/.claude/_codebase-scan.md"
  cat > "$root/.claude/codebase-profile.md" <<'PROF'
# Codebase profile

## Architecture
Feature-module architecture.

## Naming
PascalCase components.

## Testing
Vitest.

## Data access
One shared client.

## Error handling
Interceptor maps 401.
PROF
}

seed_artifact() {  # $1=root $2=name  (a bare pack-shaped command, no anchor yet)
  cat > "$1/.claude/commands/$2.md" <<ART
---
name: $2
description: Fixture artifact.
---

# $2

Do the thing.
ART
}

cite_of() {  # $1=file → the value after `top-level:`, minus the trailing period
  local v
  v=$(grep -m1 -E '^>[[:space:]]*Cite-able sources:' "$1" 2>/dev/null || true)
  v="${v#*top-level:}"
  printf '%s' "${v%.}" | sed 's/^[[:space:]]*//'
}

# ── § 1  SPA layout: tooling dot-dirs sort first, the source tree sorts last ──────────────
say "§ 1  single-root SPA — the picker must not cite tooling directories"
P1="$TD/spa"
mkdir -p "$P1"/{.husky/_,.playwright-mcp,new-architecture-standalone} \
         "$P1"/src/{assets,components,composables,views}
printf '#!/bin/sh\n' > "$P1/.husky/pre-commit"
printf 'x\n'         > "$P1/.husky/_/husky.sh"
printf '{}\n'        > "$P1/.playwright-mcp/trace.json"
printf 'readme\n'    > "$P1/new-architecture-standalone/README.md"
printf 'svg\n'       > "$P1/src/assets/logo.svg"
for i in 1 2 3 4 5 6 7 8 9 10; do printf 'export const x%s = %s\n' "$i" "$i" > "$P1/src/components/C$i.ts"; done
for i in 1 2 3; do printf '<template><div/></template>\n' > "$P1/src/views/V$i.vue"; done
printf 'export const useX = () => {}\n' > "$P1/src/composables/useX.ts"
printf '{"name":"spa"}\n' > "$P1/package.json"
seed_setup "$P1" .claude .claude/commands .husky .husky/_ .playwright-mcp \
                 new-architecture-standalone src src/assets src/components src/composables src/views
seed_artifact "$P1" add-page
bash "$ANCHORS" "$P1" --apply >/dev/null 2>&1
C1=$(cite_of "$P1/.claude/commands/add-page.md")
if [ -z "$C1" ]; then
  bad "§1 a citation line was written" "no Cite-able-sources line in the artifact"
else
  ok "§1 a citation line was written"
fi
# The defect, stated as an assertion: no directory that holds zero source files may be cited.
for junk in '.husky' '.playwright-mcp' 'new-architecture-standalone'; do
  case "$C1" in
    *"\`$junk/\`"*) bad "§1 does not cite $junk/" "citation is: $C1" ;;
    *)              ok  "§1 does not cite $junk/" ;;
  esac
done
case "$C1" in
  *'`src/'*) ok  "§1 cites the source tree" ;;
  *)         bad "§1 cites the source tree" "citation is: $C1" ;;
esac

# ── § 2  the older space-separated citation must not read as stale ───────────────────────
say "§ 2  a resolvable space-separated citation is NOT stale"
P2="$TD/spa-legacy"
mkdir -p "$P2"/src/{assets,components,composables} "$P2/.husky"
printf '#!/bin/sh\n' > "$P2/.husky/pre-commit"
printf 'svg\n' > "$P2/src/assets/logo.svg"
for i in 1 2 3; do printf 'export const y%s = %s\n' "$i" "$i" > "$P2/src/components/D$i.ts"; done
printf 'export const useY = () => {}\n' > "$P2/src/composables/useY.ts"
printf '{"name":"legacy"}\n' > "$P2/package.json"
seed_setup "$P2" .claude .claude/commands .husky src src/assets src/components src/composables
cat > "$P2/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
> Cite-able sources: `package.json`, top-level: src/assets src/components src/composables.
<!-- project-specific:end -->

Do the thing.
ART
BEFORE2=$(cite_of "$P2/.claude/commands/add-page.md")
out2=$(bash "$ANCHORS" "$P2" --apply 2>&1)
AFTER2=$(cite_of "$P2/.claude/commands/add-page.md")
if [ "$BEFORE2" = "$AFTER2" ]; then
  ok "§2 the existing citation survived untouched"
else
  bad "§2 the existing citation survived untouched" "was [$BEFORE2] now [$AFTER2]"
fi
rep2=$(printf '%s' "$out2" | sed -n 's/^Stale citations repaired:[[:space:]]*//p')
if [ "${rep2:-0}" = "0" ]; then
  ok "§2 the run reported 0 repairs"
else
  bad "§2 the run reported 0 repairs" "reported $rep2"
fi

# ── § 3  monorepo layout — the shape that already worked must keep working ───────────────
say "§ 3  monorepo — no regression on the layout that was already correct"
P3="$TD/mono"
mkdir -p "$P3"/apps/{master,tenant}/src "$P3"/libs/database/src "$P3/caddy"
for i in 1 2 3 4 5; do printf 'export class M%s {}\n' "$i" > "$P3/apps/master/src/m$i.ts"; done
for i in 1 2 3 4 5 6 7 8; do printf 'export class T%s {}\n' "$i" > "$P3/apps/tenant/src/t$i.ts"; done
for i in 1 2 3; do printf 'export class L%s {}\n' "$i" > "$P3/libs/database/src/l$i.ts"; done
printf 'reverse proxy\n' > "$P3/caddy/Caddyfile"
printf '{"name":"mono"}\n' > "$P3/package.json"
seed_setup "$P3" .claude .claude/commands apps apps/master apps/tenant caddy libs libs/database
seed_artifact "$P3" add-endpoint
bash "$ANCHORS" "$P3" --apply >/dev/null 2>&1
C3=$(cite_of "$P3/.claude/commands/add-endpoint.md")
case "$C3" in
  *'`apps/`'*) ok  "§3 cites apps/" ;;
  *)           bad "§3 cites apps/" "citation is: $C3" ;;
esac
case "$C3" in
  *'`caddy/`'*) bad "§3 does not cite caddy/ (config, no source)" "citation is: $C3" ;;
  *)            ok  "§3 does not cite caddy/ (config, no source)" ;;
esac

# ── § 4  a citation that really is dead must still be repaired ───────────────────────────
say "§ 4  a citation naming a directory that does not exist IS repaired"
P4="$TD/stale"
mkdir -p "$P4/src/components"
for i in 1 2 3; do printf 'export const z%s = %s\n' "$i" "$i" > "$P4/src/components/E$i.ts"; done
printf '{"name":"stale"}\n' > "$P4/package.json"
seed_setup "$P4" .claude .claude/commands src src/components
cat > "$P4/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
> Cite-able sources: `package.json`, top-level: `lib/`, `pkg/`.
<!-- project-specific:end -->

Do the thing.
ART
bash "$ANCHORS" "$P4" --apply >/dev/null 2>&1
C4=$(cite_of "$P4/.claude/commands/add-page.md")
case "$C4" in
  *'`lib/`'*|*'`pkg/`'*) bad "§4 the dead citation was replaced" "citation is still: $C4" ;;
  *'`src/'*)             ok  "§4 the dead citation was replaced" ;;
  *)                     bad "§4 the dead citation was replaced" "citation is: $C4" ;;
esac

# ── § 6  an anchor with NO citation line at all must gain one ────────────────────────────
say "§ 6  an anchored artifact carrying no Cite-able line is repaired, not skipped"
P6="$TD/no-cite"
mkdir -p "$P6/src/components"
for i in 1 2 3; do printf 'export const w%s = %s\n' "$i" "$i" > "$P6/src/components/F$i.ts"; done
printf '{"name":"nocite"}\n' > "$P6/package.json"
seed_setup "$P6" .claude .claude/commands src src/components
cat > "$P6/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
> Architecture: feature modules.
<!-- project-specific:end -->

Do the thing.
ART
bash "$ANCHORS" "$P6" --apply >/dev/null 2>&1
C6=$(cite_of "$P6/.claude/commands/add-page.md")
if [ -n "$C6" ]; then
  ok "§6 the missing citation line was written ($C6)"
else
  bad "§6 the missing citation line was written" "still no Cite-able-sources line — an anchored file with no citation is a permanent skip"
fi
# and the pre-existing anchor body must survive
if grep -q 'Architecture: feature modules' "$P6/.claude/commands/add-page.md"; then
  ok "§6 the existing anchor body survived"
else
  bad "§6 the existing anchor body survived" "the repair overwrote anchor content"
fi

# ── § 5  every cited directory must resolve on disk, in every fixture above ──────────────
say "§ 5  every emitted citation resolves on disk"
for pair in "$P1" "$P2" "$P3" "$P4" "$P6"; do
  for f in "$pair"/.claude/commands/*.md; do
    [ -f "$f" ] || continue
    v=$(cite_of "$f")
    case "$v" in *'<'*) continue ;; esac
    printf '%s' "$v" | tr ',[:space:]' '\n\n' | tr -d '`' | grep -v '^$' | while IFS= read -r d; do
      [ -d "$pair/${d%/}" ] || { printf '  FAIL §5 %s cites %s which does not exist\n' "${f#$TD/}" "$d"; exit 1; }
    done || bad "§5 $(basename "$pair") citations resolve"
  done
done
ok "§5 all citations resolve on disk"

say ""
say "anchor-citation fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0

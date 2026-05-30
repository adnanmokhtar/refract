#!/usr/bin/env bash
# audit-stack-leakage.sh — detect single-stack wording in universal docs (FAIL) and
# isolated tokens in pack docs (WARN). Uses stack-diversity heuristics: a line/window
# that names multiple frontend stacks, multiple backends, or frontend + backend passes.
#
# Usage: audit-stack-leakage.sh [--repo-root=<dir>]
# Exit: 1 if any FAIL; 0 otherwise (warnings on stderr).

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

cd "$REPO_ROOT" || exit 1

# Tokens that suggest a concrete stack (plan §5 + common backends / mobile).
# Note: omit bare `\bExpress\b` — matches English "express" in prose (observability copy).
STACK_PATTERN='\bv-tabs\b|\bv-text-field\b|\bv-btn\b|\bv-model\b|\bv-for\b|\bv-if\b|\bv-html\b|\b@click=|\bvee-validate\b|\bPinia\b|\bVuex\b|\bVuetify\b|\bPrimeVue\b|<TabView>|\buseState\b|\buseEffect\b|\bredux\b|\bzustand\b|\brecoil\b|\bformik\b|\breact-hook-form\b|\bMUI\b|\bMantine\b|\bshadcn\b|\bdangerouslySetInnerHTML\b|<script setup|\bSvelteKit\b|\$:|\\{#each|\\{#if|\*ngIf|\*ngFor|\bChangeDetectionStrategy\b|\bAngular Material\b|\bcreateSignal\b|\bFastAPI\b|\bFlask\b|\bexpress\.(Router|json|static)\b|\bNestJS\b|\bDjango\b|\bRails\b|\bSpring Boot\b|\bPhoenix\b|\bLaravel\b|(^|[ (/])\x2ENET\b|\bGo chi\b|\bgorilla/mux\b|\bRiverpod\b|\bMobX\b|\bdotnet\b'

failures=0
warnings=0

should_skip() {
  local p="$1"
  [[ "$p" == */references/* ]] && return 0
  [[ "$(basename "$p")" == 'STACK.md' ]] && return 0
  [[ "$p" == templates/tracks/* ]] && return 0
  [[ "$p" == tests/* ]] && return 0
  [[ "$p" == .archive/* ]] && return 0
  [[ "$p" == templates/business-domains/* ]] && return 0
  [[ "$p" == scripts/validate-migration-artifacts.sh ]] && return 0
  [[ "$p" == templates/packs/migration/_examples/* ]] && return 0
  [[ "$p" == templates/tool-adapters/*/adapter.md ]] && return 0
  return 1
}

is_universal_path() {
  local p="$1"
  [[ "$p" =~ ^commands/[^/]+\.md$ ]] && return 0
  if [[ "$p" =~ ^templates/packs/migration/ ]] && [[ "$p" != templates/packs/migration/_examples/* ]]; then
    return 0
  fi
  [[ "$p" =~ ^templates/packs/align/ ]] && return 0
  [[ "$p" =~ ^templates/packs/code-quality/ ]] && return 0
  [[ "$p" =~ ^templates/governance/ ]] && return 0
  [[ "$p" =~ ^templates/phases/ ]] && return 0
  [[ "$p" =~ ^templates/rule- ]] && [[ "$p" =~ \.md$ ]] && return 0
  [[ "$p" == templates/canonical-command-template.md ]] && return 0
  [[ "$p" == templates/decision-engine.md ]] && return 0
  [[ "$p" == templates/appendices.md ]] && return 0
  [[ "$p" =~ ^templates/tool-adapters/_ ]] && [[ "$p" =~ \.md$ ]] && return 0
  return 1
}

is_pack_path() {
  local p="$1"
  [[ "$p" =~ ^templates/packs/(frontend|backend|mobile|database|ui-ux|business|security|performance|observability|infrastructure|distributed-systems|devops|learning|testing|documentation)/ ]] && return 0
  return 1
}

# Returns 0 when the window names ≥2 stack dimensions (multi-stack list, FE+BE, etc.).
passes_stack_diversity() {
  local w="$1"
  [[ "$w" == *'<TBD:'* ]] && return 0

  local vf=0 rf=0 sf=0 af=0
  # Nuxt is Vue; Next.js / Remix are React — count meta-frameworks under their base family
  # so genuinely-diverse polyglot lines (e.g. "Next.js + NestJS") aren't false-flagged.
  grep -qE '\bVue\b|\bNuxt\b|\bv-[a-z]{2,}|\bvee-validate\b|\bPinia\b|\bVuex\b|\bVuetify\b|\bPrimeVue\b|<script setup|\b@click=' <<<"$w" && vf=1
  grep -qE '\bReact\b|\bNext\.js\b|\bRemix\b|\buseState\b|\buseEffect\b|\bdangerouslySetInnerHTML\b|\breact-hook-form\b|\bformik\b|\bshadcn\b|\bMUI\b|\bredux\b|\bzustand\b|\bMobX\b|<TabView>|\{user\.can|\{\s*user\.can' <<<"$w" && rf=1
  grep -qE '\bSvelte\b|\bSvelteKit\b|\{#each|\{#if|\$:' <<<"$w" && sf=1
  grep -qE '\bAngular\b|\*ngIf|\*ngFor|\bNgRx\b|\bAngular Material\b|\bChangeDetectionStrategy\b' <<<"$w" && af=1

  local fe=$((vf + rf + sf + af))
  # Two-pass backend count (#24):
  #  pass 1 (case-INSENSITIVE): unambiguous framework names — so lowercase policy-doc lists
  #          (django, laravel, rails, …) still count as diversity.
  #  pass 2 (case-SENSITIVE):   `Express` / `Go` — the only English-colliding tokens — match
  #          ONLY in capitalized framework form, so "express checkout" / "go to" prose does NOT
  #          count, but "Express to NestJS" does. (app.get( idioms also imply Express.)
  # Combined, lowercased, de-duped, counted.
  local be
  be=$( { grep -oiE '\b(NestJS|Django|Rails|Laravel|FastAPI|Spring Boot|Quarkus|Micronaut|Phoenix|Flask|Fastify|Hono|Ktor|ASP\.NET|dotnet|Sequelize|Prisma|SQLAlchemy|TypeORM|Mongoose)\b|app\.(get|post|put|patch|delete|use)\(|(^|[ (/])\.NET\b' <<<"$w"; grep -oE '\bExpress\b|\bGo\b' <<<"$w"; } \
        | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//' | sort -u | sed '/^$/d' | wc -l | tr -d ' ')

  [[ "$fe" -ge 2 ]] && return 0
  [[ "${be:-0}" -ge 2 ]] && return 0
  [[ "$fe" -ge 1 && "${be:-0}" -ge 1 ]] && return 0

  # Explicit slash-separated multi-stack cue from policy docs
  grep -qE 'Vue / React / Svelte / Angular' <<<"$w" && return 0
  grep -qE 'NestJS / Django / Laravel / Rails' <<<"$w" && return 0

  return 1
}

family_score_window() {
  local w
  w=$(cat)
  local n=0
  grep -qE '\bv-(tabs|for|if|model|html|btn)\b|\bvee-validate\b|\bPinia\b|\bVuex\b|\bVuetify\b|\bPrimeVue\b|<script setup|\b@click=' <<<"$w" && n=$((n + 1))
  grep -qE '\buseState\b|\buseEffect\b|\bdangerouslySetInnerHTML\b|\breact-hook-form\b|\bformik\b|\bshadcn\b|\bMUI\b|\bredux\b|\bzustand\b|\bMobX\b|<TabView>|\{user\.can' <<<"$w" && n=$((n + 1))
  grep -qE '\bSvelteKit\b|\{#each|\{#if|\$:' <<<"$w" && n=$((n + 1))
  grep -qE '\*ngIf|\*ngFor|\bNgRx\b|\bAngular Material\b|\bChangeDetectionStrategy\b' <<<"$w" && n=$((n + 1))
  grep -qE '\bFastAPI\b|\bFlask\b|\bDjango\b|\bRails\b|\bSpring Boot\b|\bPhoenix\b|\bLaravel\b|\bexpress\.(Router|json|static)\b|\bNestJS\b|\bgorilla/mux\b|\bRiverpod\b|\bKotlin\b|\bSwiftUI\b|\bFlutter\b|\bReact Native\b|(^|[ (/])\.NET\b' <<<"$w" && n=$((n + 1))
  echo "$n"
}

echo "=== audit-stack-leakage ==="
echo "Repo: $REPO_ROOT"
echo ""

while IFS= read -r -d '' f; do
  rel="${f#./}"
  should_skip "$rel" && continue

  if ! is_universal_path "$rel" && ! is_pack_path "$rel"; then
    continue
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    ln="${line%%:*}"
    rest="${line#*:}"
    start=$((ln > 1 ? ln - 1 : 1))
    end=$((ln + 1))
    window=$(sed -n "${start},${end}p" "$f" 2>/dev/null || true)

    if is_universal_path "$rel"; then
      if passes_stack_diversity "$window"; then
        continue
      fi
      echo "FAIL universal $rel:$ln — single-stack token / insufficient diversity in ±1 lines: ${rest:0:160}"
      failures=$((failures + 1))
    elif is_pack_path "$rel"; then
      start=$((ln > 5 ? ln - 5 : 1))
      end=$((ln + 5))
      window=$(sed -n "${start},${end}p" "$f" 2>/dev/null || true)
      fs=$(family_score_window <<<"$window")
      if passes_stack_diversity "$window"; then
        continue
      fi
      if [[ "${fs:-0}" -lt 2 ]]; then
        echo "WARN pack $rel:$ln — stack token without diversity in ±5 lines (${fs:-0} families): ${rest:0:120}" >&2
        warnings=$((warnings + 1))
      fi
    fi
  done < <(grep -nE -- "${STACK_PATTERN}" "$f" 2>/dev/null || true)
done < <(find . \( -path './.git' -o -path './node_modules' \) -prune -o -name '*.md' -print0)

echo ""
echo "Failures: $failures  Warnings: $warnings"
if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
exit 0

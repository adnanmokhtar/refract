#!/usr/bin/env bash
# _repo-shape.sh — the ONE answer to "where does this repo keep its source?"
#
# WHY THIS EXISTS. Every script that needed that answer invented its own, and each invention was
# right for the shape its author had in front of them and wrong for the next one. Measured over
# 2026-09-12/13, all from real repos:
#
#   detect-tracks.sh   read only the ROOT package.json  -> a turbo monorepo whose root declares
#                      eslint/prettier/turbo/typescript got 10 tracks instead of 14: no frontend,
#                      no backend, no ui-ux, while apps/web was React+Vite and apps/api NestJS.
#   detect-mcp.sh      the same assumption               -> that repo was offered no Playwright MCP,
#                      the one server every visual-verification workflow here depends on.
#   detect-mcp.sh      grep'd "$TARGET/src" for guards   -> on a monorepo that directory does not
#                      exist, the grep matched nothing, and nothing read as "no auth guards".
#   agents/skills      shipped `src/**` probes           -> 133 probes over a directory that is not
#                      there; a probe with zero hits is indistinguishable from a clean result.
#
# One shape, four wrong answers, none of which announced itself. So: one resolver, sourced by all
# of them. Add a shape HERE and every caller learns it at once.
#
# Sourced, never executed:   . "$SCRIPTS_DIR/_repo-shape.sh"
#
#   workspace_pkg_jsons <target>   every package.json below a workspace root (empty otherwise)
#   source_roots        <target>   the directories this repo actually keeps source in
#   is_monorepo         <target>   0 when a workspace/monorepo marker is present
#
# Contract: every path printed RESOLVES ON DISK, relative to <target>. A caller may cite what it
# gets back. Nothing is guessed from a framework's conventions alone — a directory that does not
# exist is never returned, because that is the failure this file was written to end.

# --- is this a workspace/monorepo root? ------------------------------------------------------
is_monorepo() {
  local t="${1:-.}"
  [ -f "$t/pnpm-workspace.yaml" ] && return 0
  [ -f "$t/turbo.json" ] && return 0
  [ -f "$t/nx.json" ] && return 0
  [ -f "$t/lerna.json" ] && return 0
  [ -f "$t/rush.json" ] && return 0
  [ -f "$t/nest-cli.json" ] && grep -q '"monorepo"[[:space:]]*:[[:space:]]*true' "$t/nest-cli.json" 2>/dev/null && return 0
  [ -f "$t/package.json" ] && grep -q '"workspaces"' "$t/package.json" 2>/dev/null && return 0
  return 1
}

# --- every workspace member's package.json ---------------------------------------------------
# Depth 2 covers apps/<name>/ and packages/<name>/, which is where every layout in the wild puts
# them; depth 1 covers a flat workspace. The root's own package.json is excluded — the caller
# already has it, and returning it twice double-counts its deps.
workspace_pkg_jsons() {
  local t="${1:-.}" p
  is_monorepo "$t" || return 0
  for p in "$t"/*/*/package.json "$t"/*/package.json; do
    [ -f "$p" ] || continue
    [ "$p" = "$t/package.json" ] && continue
    case "$p" in */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*|*/.nuxt/*) continue ;; esac
    printf '%s\n' "$p"
  done
}

# --- where the source actually lives ----------------------------------------------------------
# Order of resolution, first hit wins, and every hit is confirmed on disk:
#   1. monorepo      apps/*/src, packages/*/src, libs/*/src — and the member root when it has no src/
#   2. src/          the single-package convention, when it is really there
#   3. lib/          Flutter and most Dart packages
#   4. dense dirs    Nuxt and friends root their code at pages/, components/, composables/… —
#                    no src/ at all, so fall back to measuring which top-level directories
#                    actually hold source files. Never a hardcoded framework list: the same
#                    measurement answers for a layout nobody has thought of yet.
source_roots() {
  local t="${1:-.}" d found=0
  if is_monorepo "$t"; then
    for d in "$t"/apps/*/src "$t"/packages/*/src "$t"/libs/*/src "$t"/services/*/src; do
      [ -d "$d" ] || continue
      printf '%s\n' "${d#$t/}"; found=1
    done
    if [ "$found" -eq 0 ]; then
      for d in "$t"/apps/* "$t"/packages/* "$t"/libs/*; do
        [ -d "$d" ] || continue
        printf '%s\n' "${d#$t/}"; found=1
      done
    fi
    [ "$found" -eq 1 ] && return 0
  fi

  [ -d "$t/src" ] && { printf 'src\n'; return 0; }
  [ -d "$t/lib" ] && [ -f "$t/pubspec.yaml" ] && { printf 'lib\n'; return 0; }

  # Measured fallback: top-level directories ranked by how much source they hold. A directory
  # with no source is not a source root whatever it is called, and a dot-directory never is.
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/repo-shape.XXXXXX")" || return 0
  for d in "$t"/*/; do
    d="${d%/}"
    case "${d##*/}" in .*|node_modules|dist|build|coverage|vendor|public|assets|docs|test|tests|__pycache__) continue ;; esac
    local n
    n=$(find "$d" -maxdepth 3 -type f \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
          -o -name '*.vue' -o -name '*.svelte' -o -name '*.dart' -o -name '*.py' -o -name '*.rb' \
          -o -name '*.go' -o -name '*.rs' -o -name '*.java' -o -name '*.kt' -o -name '*.php' \) 2>/dev/null | wc -l | tr -d ' ')
    [ "${n:-0}" -gt 0 ] && printf '%s %s\n' "$n" "${d##*/}" >> "$tmp"
  done
  sort -rn "$tmp" 2>/dev/null | head -6 | awk '{print $2}'
  rm -f "$tmp"
}

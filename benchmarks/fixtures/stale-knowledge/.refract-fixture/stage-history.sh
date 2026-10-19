#!/usr/bin/env bash
# stage-history.sh - give a STAGED copy of the stale-knowledge fixture a deterministic history.
#
#   bash <copy>/.refract-fixture/stage-history.sh <copy>
#
# `benchmarks/run.sh --fixture=stale-knowledge` stages the tree with one commit. The learning detectors read history:
# a dead path is RENAMED (with its successor) or DELETED only when git saw it go, a dead symbol needs the commit that
# removed it (DOCER: a name no commit ever removed never existed here), and the derived files and the extraction oracle
# record the sha they were derived at (`git rev-list --count <sha>..HEAD -- <sources>`). This script replaces the
# copy's .git with a fixed 15-commit history built from .refract-fixture/history/ (commits.tsv, actions.tsv and the
# old file versions under files/), then deletes .refract-fixture/, so the final tree equals the staged copy minus
# that directory.
#
# Deterministic: fixed author and committer, fixed dates per commit, no user or system git config, so step 0 always
# gets the sha the derived files cite. It refuses the fixture itself and the Refract repo (anything holding DEFECTS.md
# or benchmarks/run.sh). A case-only rename (ApiClient.ts -> apiClient.ts) is staged safely on a case-insensitive
# filesystem: the final file is copied aside before the old name is written.
set -euo pipefail

die() { printf 'stage-history: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 1 ] || die "usage: stage-history.sh <staged copy of the stale-knowledge fixture>"
[ -d "$1" ] || die "no such directory: $1"
T="$(cd "$1" && pwd)"
[ ! -e "$T/DEFECTS.md" ] || die "refusing: $T holds DEFECTS.md (the fixture or an answer key, not a staged copy)"
[ ! -e "$T/benchmarks/run.sh" ] || die "refusing: $T is the Refract repo, not a staged copy"
H="$T/.refract-fixture/history"
[ -f "$H/commits.tsv" ] && [ -f "$H/actions.tsv" ] || die "no $H/commits.tsv: run this on a copy staged by run.sh"
command -v git >/dev/null 2>&1 || die "git is not on PATH"

TAB="$(printf '\t')"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/stale-knowledge-history.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir "$WORK/final" "$WORK/hist" "$WORK/aside"
cp -R "$H/." "$WORK/hist/"

rm -rf "$T/.git" "$T/.refract-fixture"
( cd "$T" && tar -cf - . ) | ( cd "$WORK/final" && tar -xf - )

export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 LC_ALL=C TZ=UTC
g() {
  git -C "$T" -c user.name=bench -c user.email=bench@localhost -c commit.gpgsign=false \
    -c tag.gpgsign=false -c core.hooksPath=/dev/null -c init.defaultBranch=main -c core.autocrlf=false "$@"
}
overlay() { printf '%s/hist/files/%s.hist' "$WORK" "$1"; }
place() {   # place <source file> <repo-relative destination>
  mkdir -p "$(dirname "$T/$2")"
  cp "$1" "$T/$2"
}
tilde() { printf '%s' "$1" | sed 's#/#~#g'; }

apply_step() {
  local step="$1" s verb a b tmp
  while IFS="$TAB" read -r s verb a b <&4; do
    [ "$s" = "$step" ] || continue
    case "$verb" in
      old|only)   [ -f "$(overlay "$(tilde "$a")")" ] || die "missing overlay for $a"; place "$(overlay "$(tilde "$a")")" "$a" ;;
      put)        [ -f "$(overlay "$b")" ] || die "missing overlay $b"; place "$(overlay "$b")" "$a" ;;
      from-final) tmp="$WORK/aside/$(tilde "$b")"; cp "$WORK/final/$b" "$tmp"; rm -f "$T/$b"; place "$tmp" "$a" ;;
      absent)     rm -f "$T/$a" ;;
      final)      place "$WORK/final/$a" "$a" ;;
      mv)         mkdir -p "$(dirname "$T/$b")"; g mv "$a" "$b" ;;
      rm)         g rm -q "$a" ;;
      *)          die "unknown action '$verb' in actions.tsv" ;;
    esac
  done 4< "$WORK/hist/actions.tsv"
}

sync_final() {
  find "$T" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  ( cd "$WORK/final" && tar -cf - . ) | ( cd "$T" && tar -xf - )
}

g init -q
n=0
while IFS="$TAB" read -r step date tag subject <&3; do
  case "$step" in ''|'#'*) continue ;; esac
  if [ "$step" = "final" ]; then sync_final; else apply_step "$step"; fi
  g add -A
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" g commit -q --allow-empty -m "$subject"
  if [ -n "$tag" ] && [ "$tag" != "-" ]; then
    GIT_COMMITTER_DATE="$date" g tag "$tag"
  fi
  n=$((n + 1))
done 3< "$WORK/hist/commits.tsv"

[ -z "$(g status --porcelain)" ] || die "the final tree does not match the staged copy (git status is not clean)"
printf 'stage-history: %d commits, root %s, HEAD %s\n' "$n" "$(g rev-list --max-parents=0 HEAD | cut -c1-10)" "$(g rev-parse --short=10 HEAD)"

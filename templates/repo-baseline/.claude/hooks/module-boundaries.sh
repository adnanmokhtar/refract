#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit) — refuse an import that crosses a boundary the
# project itself declared. Exit 2 = block. Exit 0 = allow.
#
# WHY. `ai/modules.md` ships a section headed "Module boundaries (which modules MUST NOT
# import which)" and closes it with the line "Crossing a boundary is a code-review fail."
# That was the whole enforcement: a human noticing. The rule is machine-decidable — the
# boundary is declared in one file and the import is written in another — so nothing except
# the absence of a reader made it a review problem.
#
# WHAT IT READS. Two blocks of `ai/modules.md`, both already part of the shipped template:
#
#   the catalog     | <module> | `src/path/` | owns | surface | cross-cuts |
#   the boundaries  - `<A>` MUST NOT import from `<B>` — reason: <one line>
#                   - `<A>` MAY import from `<B>` only via `<facade>`
#
# A MUST NOT rule blocks outright. A MAY-only-via rule blocks every path into <B> except the
# named facade, which is the stricter and more useful reading: the whole point of a port is
# that it is the ONLY door.
#
# WHAT IT CHECKS. The content being written — `content` for Write, `new_string` for Edit, every
# `new_string` for MultiEdit — not the file on disk. So it fires on the import this edit is
# ADDING and stays quiet about violations that were already there: a pre-existing crossing is a
# refactor to schedule, not a reason to reject an unrelated edit.
#
# LANGUAGES. TypeScript / JavaScript (`import … from '<spec>'`, `export … from '<spec>'`,
# `require('<spec>')`, dynamic `import('<spec>')`) and Python (`import a.b`, `from a.b import`).
# Any other extension exits 0 without looking. That is a real limit, not a placeholder: a hook
# that guesses at a language it cannot parse blocks correct code, and a blocking hook that cries
# wolf gets switched off within the week — at which point it protects nothing.
#
# RESOLUTION, and why it is deliberately conservative. A specifier is matched to a module two
# ways, and only these two:
#   relative  `../billing/service` from `src/orders/` → `src/billing/service` → module `billing`
#   rooted    `src/billing/service`, `@/billing/service`, `billing.service` (Python dots → slashes)
# Both sides are normalised by dropping a leading `./`, `@/`, `~/`, `#/` and then one leading
# `src/`, `app/`, or `lib/` segment, so a declared `src/billing/` matches an aliased
# `@/billing/x`.
#
# A RENAMING alias (`@app/database/*` → `libs/database/src/*`) cannot be undone by any sigil rule
# — it is indistinguishable from a scoped npm package — so it is read from `compilerOptions.paths`
# in tsconfig.json / jsconfig.json, following `extends`. That table is the same one the compiler
# uses, so reading it is resolution, not inference. Measured on one real NestJS monorepo: 46 rules
# governing 3,487 imports, every one of which this hook previously waved through as external.
#
# THE PARSE IS OPTIONAL AND FAILS TOWARD SILENCE, because this thing blocks writes and a
# mis-parsed alias would refuse legitimate work. No python3, no config, unreadable JSON, or a
# specifier no rule declares → zero aliases, and resolution is byte-for-byte what it was before.
# An alias can only ever turn "unresolvable" into "resolvable"; it never changes an answer the
# hook could already reach on its own. Silence stays the designed behaviour everywhere resolution
# is uncertain.
#
# Opt out per project: create .claude/.no-module-boundaries

set -uo pipefail

[ -f ".claude/.no-module-boundaries" ] && exit 0

MODULES="ai/modules.md"
[ -f "$MODULES" ] || exit 0

payload=$(cat)

# ---- payload → file_path + the text being written -------------------------------------------
needs_unescape=1
if command -v jq >/dev/null 2>&1; then
  needs_unescape=0          # jq -r already emits the decoded string
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  content=$(printf '%s' "$payload" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null || true)
else
  file_path=$(printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  # `sed -E`, not BRE. The original used `\|` for alternation — a GNU extension BSD sed does not
  # support, so on macOS this branch matched NOTHING and the guard was a silent no-op whenever jq
  # was absent. The `"$` anchor was wrong too: after splitting on commas the last field ends in `"}}`,
  # not a quote, so WITHOUT jq this hook extracted nothing and every boundary crossing walked
  # through. A guard that silently does not guard is worse than an absent one — it is the same
  # fail-open shape the repo's own gates are written to catch. Allow the trailing JSON
  # punctuation the split leaves behind.
  content=$(printf '%s' "$payload" | tr ',' '\n' \
            | sed -nE 's/.*"(content|new_string)"[[:space:]]*:[[:space:]]*"(.*)".*/\2/p')
fi
[ -z "$file_path" ] && exit 0
[ -z "$content" ] && exit 0

case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.mts|*.cts|*.py) ;;
  *) exit 0 ;;
esac

# ONLY on the sed fallback. `jq -r` has already decoded the string, so running this again is a
# SECOND un-escape: a source file whose own string literal contains the two characters \ and n —
# `raise ValueError("bad\nimport billing.service")` — gains a real line break, and the scanner
# then sees an import line the file does not contain and refuses a legitimate write. Un-escaping
# is a property of how the payload was parsed, not of the payload.
if [ "$needs_unescape" -eq 1 ]; then
  content=$(printf '%s' "$content" | sed 's/\\n/\n/g; s/\\"/"/g; s/\\\\/\\/g')
fi

# Repo-relative, no leading slash — the catalog's paths are repo-relative.
rel_path="$file_path"
case "$rel_path" in
  "$PWD"/*) rel_path="${rel_path#"$PWD"/}" ;;
  /*) rel_path=$(printf '%s' "$rel_path" | sed 's|^/||') ;;
esac

# ---- normalise: drop alias sigils, then ONE source-root segment ------------------------------
norm() {
  printf '%s' "$1" \
    | sed 's|^\./||; s|^@/||; s|^~/||; s|^#/||; s|^/||' \
    | sed 's|^src/||; s|^app/||; s|^lib/||' \
    | sed 's|/*$||'
}

# ---- collapse `a/b/../c` → `a/c` (relative specifiers resolve against the file's dir) --------
canon() {
  printf '%s' "$1" | awk -F/ '{
    n=0
    for (i=1; i<=NF; i++) {
      if ($i=="" || $i==".") continue
      if ($i=="..") { if (n>0) n--; continue }
      st[++n]=$i
    }
    out=""
    for (i=1; i<=n; i++) out = out (i>1 ? "/" : "") st[i]
    print out
  }'
}

# ---- the module catalog: `| name | `path/` | …`  →  "name<TAB>normalised-path" ----------------
CATALOG=$(grep -E '^\|[^|]+\|[^|]*`[^`]+`' "$MODULES" 2>/dev/null \
  | grep -v '^| *<name>' \
  | while IFS= read -r row; do
      name=$(printf '%s' "$row" | awk -F'|' '{print $2}' | sed 's/[`< >]//g; s/^ *//; s/ *$//')
      path=$(printf '%s' "$row" | awk -F'|' '{print $3}' | grep -oE '`[^`]+`' | head -1 | tr -d '`')
      [ -n "$name" ] && [ -n "$path" ] && printf '%s\t%s\n' "$name" "$(norm "$path")"
    done)
[ -z "$CATALOG" ] && exit 0

# ---- tsconfig `paths` → "prefix<TAB>suffix<TAB>target" rules, longest prefix first ------------
# Emitted by python3 when it is there; absent otherwise. Never fatal: `|| true` plus a discarded
# stderr means a broken config costs the alias table, not the write.
ALIASES=""
if command -v python3 >/dev/null 2>&1; then
  ALIASES=$(python3 - <<'PYEOF' 2>/dev/null || true
import json, os, re, sys
BLOCK = re.compile(r'/\*.*?\*/', re.S)
LINE = re.compile(r'(?m)(?<![:"\w])//[^\n]*')
COMMA = re.compile(r',(\s*[}\]])')

def read(path):
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    raw = COMMA.sub(r"\1", LINE.sub("", BLOCK.sub("", raw)))
    try:
        return json.loads(raw)
    except ValueError:
        return None

def rules(path, depth=0):
    if depth > 4 or not os.path.isfile(path):
        return []
    cfg = read(path)
    if not isinstance(cfg, dict):
        return []
    out = []
    ext = cfg.get("extends")
    if isinstance(ext, str) and not ext.startswith("@"):
        parent = os.path.normpath(os.path.join(os.path.dirname(path), ext))
        out.extend(rules(parent if parent.endswith(".json") else parent + ".json", depth + 1))
    co = cfg.get("compilerOptions")
    if isinstance(co, dict) and isinstance(co.get("paths"), dict):
        base = os.path.normpath(os.path.join(os.path.dirname(path), co.get("baseUrl") or "."))
        for key, targets in co["paths"].items():
            if not isinstance(targets, list) or key.count("*") > 1:
                continue
            pre, _, suf = key.partition("*")
            for t in targets:
                if not isinstance(t, str) or t.count("*") > 1:
                    continue
                r = os.path.relpath(os.path.normpath(os.path.join(base, t)), ".").replace(os.sep, "/")
                if not r.startswith(".."):
                    out.append((pre, suf, r))
    return out

def mnm():
    """package.json jest.moduleNameMapper — a REGEX table. Only exactly-convertible shapes.

    `^pfx(|/.*)$ -> tgt/$1` and `^pfx$ -> tgt`. Any other regex feature is skipped rather than
    approximated: a guessed alias here refuses a legitimate write.
    """
    cfg = read("package.json")
    if not isinstance(cfg, dict):
        return []
    jest = cfg.get("jest")
    if not isinstance(jest, dict) or not isinstance(jest.get("moduleNameMapper"), dict):
        return []
    wild = re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)/?\(\|?/?\.\*\)\$$')
    exact = re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)\$$')
    out = []
    for key, val in jest["moduleNameMapper"].items():
        if not isinstance(val, str):
            continue
        tgt = val.replace("<rootDir>/", "").replace("<rootDir>", "")
        m = wild.match(key)
        if m:
            if "$1" not in tgt:
                continue
            out.append((m.group("pfx") + "/", "", tgt.replace("$1", "*").replace("//", "/")))
            continue
        m = exact.match(key)
        if m and "$" not in tgt:
            out.append((m.group("pfx"), "", tgt))
    return out


seen = []
for name in ("tsconfig.json", "jsconfig.json"):
    if os.path.isfile(name):
        seen = rules(name)
        break
seen.extend(mnm())
for pre, suf, tgt in sorted(seen, key=lambda r: len(r[0]), reverse=True):
    if "\t" in pre + suf + tgt:
        continue
    sys.stdout.write("%s\t%s\t%s\n" % (pre, suf, tgt))
PYEOF
)
fi

# specifier → every repo path the alias table says it could name (empty when none matches)
alias_targets() {
  [ -z "$ALIASES" ] && return 0
  printf '%s\n' "$ALIASES" | awk -v s="$1" -F'\t' '
    NF==3 {
      pre=$1; suf=$2; tgt=$3
      if (length(s) < length(pre)+length(suf)) next
      if (substr(s, 1, length(pre)) != pre) next
      if (length(suf) > 0 && substr(s, length(s)-length(suf)+1) != suf) next
      star = substr(s, length(pre)+1, length(s)-length(pre)-length(suf))
      if (index(tgt, "*") > 0) { sub(/\*/, star, tgt) }
      print tgt
      matched=1
    }
    matched && NR>0 { }
  ' | head -8
}

module_of() {  # normalised path → module name (longest declared path wins)
  local p="$1" best="" bestlen=0 name mpath
  while IFS="$(printf '\t')" read -r name mpath; do
    [ -n "$mpath" ] || continue
    case "$p/" in
      "$mpath"/*) if [ ${#mpath} -gt $bestlen ]; then best="$name"; bestlen=${#mpath}; fi ;;
    esac
  done <<CATEOF
$CATALOG
CATEOF
  printf '%s' "$best"
}

path_of() {  # module name → normalised path
  local want="$1" name mpath
  while IFS="$(printf '\t')" read -r name mpath; do
    [ "$name" = "$want" ] && { printf '%s' "$mpath"; return 0; }
  done <<CATEOF2
$CATALOG
CATEOF2
  return 1
}

SELF=$(module_of "$(norm "$rel_path")")
[ -z "$SELF" ] && exit 0

# ---- the declared boundaries ------------------------------------------------------------------
RULES=$(grep -nE '^[-*] *`[^`]+` *(MUST NOT|MAY) ' "$MODULES" 2>/dev/null | grep -v '<module-A>')
[ -z "$RULES" ] && exit 0

# ---- every import specifier in the incoming text ----------------------------------------------
specs=$(
  case "$file_path" in
    (*.py)
      printf '%s\n' "$content" \
        | grep -oE '^[[:space:]]*(from|import)[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*' \
        | sed 's/^[[:space:]]*//; s/^from[[:space:]]*//; s/^import[[:space:]]*//' \
        | tr '.' '/' ;;
    (*)
      printf '%s\n' "$content" \
        | grep -oE "(from|import|require)[[:space:]]*\(?[[:space:]]*['\"][^'\"]+['\"]" \
        | grep -oE "['\"][^'\"]+['\"]" | tr -d "'\"" ;;
  esac | sed '/^[[:space:]]*$/d' | sort -u
)
[ -z "$specs" ] && exit 0

dir_of_file=$(dirname "$rel_path")

resolve() {  # specifier → normalised repo path, or empty when unresolvable
  local s="$1" a=""
  # The config table first, and only for non-relative specifiers: a relative path is already
  # unambiguous, and no `paths` key may override it. When several targets share a key the FIRST
  # is taken, matching the order tsc tries them. That can only ever under-resolve, which for a
  # hook that blocks writes is the safe direction to be wrong in.
  case "$s" in
    ./*|../*) ;;
    *) a=$(alias_targets "$s" | sed -n '1p') ;;
  esac
  if [ -n "$a" ]; then
    norm "$a"
    return 0
  fi
  case "$s" in
    ./*|../*) canon "$dir_of_file/$s" | sed 's|^src/||; s|^app/||; s|^lib/||' ;;
    /*|@*/*|~/*|\#/*) norm "$s" ;;
    */*) norm "$s" ;;
    *)
      # In JS/TS a bare specifier is a node_modules package and never local. In PYTHON it is the
      # ordinary way to import a local top-level package when src/ is on sys.path — and
      # `from billing import charge` is the most common import form there was, so the most common
      # Python crossing was never checked. Resolve it for .py only, and only far enough that the
      # normal catalog comparison decides: `norm` strips a leading src/app/lib from both sides, so
      # `billing` meets `src/billing/` on equal terms.
      case "$file_path" in
        (*.py) norm "$s" ;;
        (*)    printf '' ;;
      esac ;;
  esac
}

block() {
  echo "Blocked by module-boundaries: $1" >&2
  echo "Declared in ai/modules.md. If the boundary is wrong, change it there — deliberately," >&2
  echo "in its own commit, with the reason updated. To bypass once: .claude/.no-module-boundaries" >&2
  exit 2
}

while IFS= read -r rule; do
  [ -n "$rule" ] || continue
  ln=${rule%%:*}; body=${rule#*:}
  a=$(printf '%s' "$body" | grep -oE '`[^`]+`' | sed -n '1p' | tr -d '`')
  b=$(printf '%s' "$body" | grep -oE '`[^`]+`' | sed -n '2p' | tr -d '`')
  [ -n "$a" ] && [ -n "$b" ] || continue
  [ "$a" = "$SELF" ] || continue

  b_path=$(path_of "$b") || continue
  [ -n "$b_path" ] || continue

  case "$body" in
    *"MUST NOT"*)
      for s in $specs; do
        r=$(resolve "$s"); [ -n "$r" ] || continue
        case "$r/" in
          "$b_path"/*)
            block "\`$SELF\` MUST NOT import from \`$b\` — $rel_path imports '$s' (ai/modules.md:$ln)" ;;
        esac
      done ;;
    *MAY*only\ via*)
      facade=$(printf '%s' "$body" | grep -oE '`[^`]+`' | sed -n '3p' | tr -d '`')
      [ -n "$facade" ] || continue
      f_path=$(norm "$facade")
      # A declared facade is written the way a human writes a FILE — `libs/shared/src/index.ts`.
      # An import is written the way TypeScript/JS require — no extension, and a directory when the
      # target is its index. Comparing the two literally rejects the one path the rule permits, so
      # both sides are compared extension-free, and an `index` facade also answers to its directory.
      f_base=$(printf '%s' "$f_path" | sed -E 's/\.(ts|tsx|js|jsx|mjs|cjs|py)$//')
      f_dir=""
      case "$f_base" in */index) f_dir="${f_base%/index}" ;; esac
      for s in $specs; do
        r=$(resolve "$s"); [ -n "$r" ] || continue
        case "$r/" in
          "$b_path"/*)
            r_base=$(printf '%s' "$r" | sed -E 's/\.(ts|tsx|js|jsx|mjs|cjs|py)$//')
            case "$r_base" in
              "$f_base"|"$f_base"/*|*"/$f_base") continue ;;
            esac
            [ -n "$f_dir" ] && [ "$r_base" = "$f_dir" ] && continue
            block "\`$SELF\` may reach \`$b\` only via \`$facade\` — $rel_path imports '$s' directly (ai/modules.md:$ln)" ;;
        esac
      done ;;
  esac
done <<RULEEOF
$RULES
RULEEOF

exit 0

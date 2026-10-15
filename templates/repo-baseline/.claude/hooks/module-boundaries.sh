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
# Catalog paths are repo-relative. A row under a heading that names a source root in backticks —
# `## apps/api (`apps/api/src/`)` — may be written relative to that root; see SECTIONS below.
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
# — it is indistinguishable from a scoped npm package — so it is read from the data the compiler
# and the package manager read, with the same semantics as the Refract repo's
# scripts/rank-source-files.py (its config functions are embedded below, AST-identical):
#   * `compilerOptions.paths` from the NEAREST tsconfig.json / jsconfig.json at or above the
#     WRITTEN file's directory, up to the project root (where tsconfig.base.json also counts).
#     `extends` is followed (string or list; a package base only when installed), and a child's
#     `paths` REPLACES its parent's, as tsc does. A scope that declares no alias falls through to
#     the next one up. Jest `moduleNameMapper` in that directory's package.json joins the scope.
#   * workspace members (pnpm-workspace.yaml, package.json `workspaces`, lerna.json): a specifier
#     naming one resolves through its `exports` (else types/main), mapped from build output back
#     to source by the package's own outDir → rootDir, and only to a source file that exists.
# Reading only the root config was a real miss: a pnpm monorepo whose `@/*` lives in
# apps/web/tsconfig.json and whose contracts are a workspace package read ZERO rules, and every
# aliased import there went unchecked (2026-10-15, a real NestJS + React monorepo).
#
# THE PARSE IS OPTIONAL AND FAILS TOWARD SILENCE, because this thing blocks writes and a
# mis-parsed alias would refuse legitimate work. No python3, no config, unreadable JSON, or a
# specifier no rule declares → zero aliases, and resolution is byte-for-byte what it was before.
# An alias can only ever turn "unresolvable" into "resolvable"; it never changes an answer the
# hook could already reach on its own. Silence stays the designed behaviour everywhere resolution
# is uncertain. That is also why rank-source-files.py's two non-alias rules are NOT ported:
# `baseUrl`-rooted lookup and the nearest-package `@/` fallback would both re-aim specifiers this
# hook already resolves (`src/x`, `@/x`) — a different answer, not a new one.
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
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.mts|*.cts|*.py|*.vue|*.svelte|*.dart) ;;
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

TAB=$(printf '\t')

# ---- SECTIONS: headings that name a source root -----------------------------------------------
# A monorepo catalog is often split per app, and each section writes its paths relative to the
# root its heading names:
#
#   ## apps/api (`apps/api/src/`)
#   | `products` | `modules/products` | … |
#
# Read repo-relative, `modules/products` matched no file in the repo, so on a real NestJS + React
# monorepo (2026-10-15) no written file mapped to any module and a declared boundary could never
# fire. The root is the FIRST backticked token in a heading that contains a `/`; it holds until a
# heading at the same or a higher level that names none. Headings inside a ``` / ~~~ fence are
# not headings. Prepended to both awk programs below, so the catalog and the rules agree on it.
AWK_SECTION='
/^[ \t]*(```|~~~)/ { fence = !fence }
!fence && /^#+[ \t]/ {
  lvl = match($0, /[^#]/) - 1; r = ""; s = $0
  while (match(s, /`[^`]+`/)) {
    t = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH)
    if (t ~ /\//) { r = t; break }
  }
  sub(/^\.\//, "", r); sub(/\/+$/, "", r)
  if (r != "") { root = r; rootlvl = lvl } else if (root != "" && lvl <= rootlvl) root = ""
  next
}'

# ---- the module catalog: `| name | `path/` | …`  →  "name<TAB>normalised-path<TAB>root" -------
# ONE awk, not a loop of subshells: the loop forked ~7 processes per row, and a real 93-row catalog
# cost several seconds on every TS write before a single import was looked at (2026-10-15). The
# path goes through the same steps as norm() above, in the same order.
#
# A row under a rooted section is joined to its root ONLY when that is the one reading the disk
# supports: the path does not already start with the root, does not exist as written, and does
# exist under the root. Everything else — a repo-relative path, one that already carries the
# root, a path that exists both ways, one that exists neither way — is read exactly as before. The
# loop is shell builtins only (`[ -e ]`, `case`), so it adds no process per row.
CATALOG=$(awk -F'|' "$AWK_SECTION"'
    /^\|[^|]+\|[^|]*`[^`]+`/ && !/^\| *<name>/ {
      name = $2; gsub(/[`< >]/, "", name)
      if (!match($3, /`[^`]+`/)) next
      p = substr($3, RSTART + 1, RLENGTH - 2)
      sub(/^\.\//, "", p)
      if (name == "" || p == "") next
      printf "%s\t%s\t%s\n", name, p, root
    }' "$MODULES" 2>/dev/null \
  | while IFS="$TAB" read -r name p root; do
      if [ -n "$root" ]; then
        case "$p/" in
          ("$root"/*) ;;
          (*) if [ ! -e "$p" ] && [ -e "$root/$p" ]; then p="$root/$p"; fi ;;
        esac
      fi
      printf '%s\t%s\t%s\n' "$name" "$p" "$root"
    done \
  | awk -F'\t' '{
      p = $2
      sub(/^@\//, "", p); sub(/^~\//, "", p); sub(/^#\//, "", p); sub(/^\//, "", p)
      sub(/^src\//, "", p); sub(/^app\//, "", p); sub(/^lib\//, "", p)
      sub(/\/*$/, "", p)
      printf "%s\t%s\t%s\n", $1, p, $3
    }')
[ -z "$CATALOG" ] && exit 0

module_of() {  # normalised path → "name<TAB>section-root" (longest declared path wins)
  local p="$1" best="" broot="" bestlen=0 name mpath root
  while IFS="$TAB" read -r name mpath root; do
    [ -n "$mpath" ] || continue
    case "$p/" in
      "$mpath"/*) if [ ${#mpath} -gt $bestlen ]; then best="$name"; broot="$root"; bestlen=${#mpath}; fi ;;
    esac
  done <<CATEOF
$CATALOG
CATEOF
  printf '%s\t%s' "$best" "$broot"
}

# Module name → normalised path. Two apps may both carry an `orders`, so a name is looked up in
# the rule's own section when the rule sits under a rooted heading, else in the writer's section
# first (where a catalog with no rooted heading puts every row, so the first row wins as it always
# did), else anywhere — but only when exactly one row carries it. Ambiguous → no path → no block.
path_of() {  # name, rule-section, writer-section
  local want="$1" scope="$2" own="$3" name mpath root first="" n=0
  while IFS="$TAB" read -r name mpath root; do
    [ "$name" = "$want" ] || continue
    [ -z "$scope" ] || [ "$root" = "$scope" ] || continue
    [ "$root" = "$own" ] && { printf '%s' "$mpath"; return 0; }
    [ -z "$first" ] && first="$mpath"
    n=$((n+1))
  done <<CATEOF2
$CATALOG
CATEOF2
  [ "$n" -eq 1 ] && { printf '%s' "$first"; return 0; }
  return 1
}

hit=$(module_of "$(norm "$rel_path")")
SELF=${hit%%"$TAB"*}; SELF_ROOT=${hit#*"$TAB"}
[ -z "$SELF" ] && exit 0

# ---- the declared boundaries: "line<TAB>section-root<TAB>rule" --------------------------------
# A rule under a rooted heading binds that section's modules only; a rule anywhere else binds
# every module of that name.
RULES=$(awk "$AWK_SECTION"'
    /^[-*] *`[^`]+` *(MUST NOT|MAY) / && !/<module-A>/ { printf "%d\t%s\t%s\n", NR, root, $0 }
  ' "$MODULES" 2>/dev/null)
[ -z "$RULES" ] && exit 0
# Only a rule whose subject is this module can fire. Without one there is nothing to resolve, and
# the alias read below — the one python3 start in this hook — is skipped.
printf '%s\n' "$RULES" | grep -qF "\`$SELF\`" || exit 0

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

# pubspec's `name` is the ONLY thing that separates this app's own `package:` imports from a
# dependency's. Without it the hook either blocks on flutter/ (which is not in this repo) or
# resolves nothing at all. Read once, at column 0, so a nested `name:` cannot stand in for it.
DART_PKG=""
if [ -f "pubspec.yaml" ]; then
  DART_PKG=$(sed -n 's/^name:[[:space:]]*["'"'"']\{0,1\}\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' \
             pubspec.yaml | head -1)
fi

# One python3 run per write, and only when it can matter: a TS-family file, a module the catalog
# knows, a rule naming it, and at least one non-relative specifier. Input by environment, output
# "spec<TAB>repo-path" for every specifier a config or a workspace resolves; nothing else.
# `-I` keeps the project's own directory off sys.path — this runs inside arbitrary checkouts.
RESOLVED=""
case "$file_path" in
  (*.py|*.dart) nonrel="" ;;
  (*) nonrel=$(printf '%s\n' "$specs" | grep -vE '^\.\.?/' || true) ;;
esac
# The script is read into a variable rather than fed as a heredoc INSIDE `$( )`: bash 3.2 (macOS)
# parses a command substitution's heredoc body as shell, and a quote or `#` in the python broke it.
if [ -n "$nonrel" ] && command -v python3 >/dev/null 2>&1; then
  IFS= read -r -d '' PYSRC <<'PYEOF'
import glob as _glob, json, os, re, sys
from fnmatch import fnmatch

PRUNE = {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build", ".next",
         ".mypy_cache", ".pytest_cache", "vendor", "target", ".tox", "coverage"}
TRAILING_COMMA = re.compile(r',(\s*[}\]])')
MNM_SHAPES = (
    re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)/?\(\|?/?\.\*\)\$$'),
    re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)\$$'),
)
CONFIG_NAMES = ("tsconfig.json", "jsconfig.json")
ROOT_CONFIG_NAMES = ("tsconfig.json", "jsconfig.json", "tsconfig.base.json")
EXPORT_CONDITIONS = ("source", "types", "typings", "import", "module", "require", "node",
                     "browser", "development", "production", "default")
BUILD_EXT = (".d.ts", ".d.mts", ".d.cts", ".js", ".mjs", ".cjs", ".jsx")
TS_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts")
SFC_EXT = (".vue", ".svelte")
SOURCE_EXT = TS_EXT + (".py",) + SFC_EXT + (".dart",)
JS_TO_TS = {".js": (".ts", ".tsx"), ".jsx": (".tsx",), ".mjs": (".mts",), ".cjs": (".cts",)}

# ---- BEGIN shared: these functions are AST-identical to scripts/rank-source-files.py (Refract
# repo; docstrings and comments dropped). tests/hooks/run.sh fails when the two drift. ---------

# A scanner, not a regex: `"@/*": ["src/*"]` puts a literal /* inside a STRING, and a regex
# stripper opened a comment there that ate compilerOptions — zero rules on the stock Vite tsconfig.
def _strip_jsonc_comments(raw):
    out = []
    i, n = 0, len(raw)
    while i < n:
        c = raw[i]
        if c == '"':
            out.append(c)
            i += 1
            while i < n:
                c = raw[i]
                out.append(c)
                i += 1
                if c == "\\" and i < n:
                    out.append(raw[i])
                    i += 1
                elif c == '"':
                    break
            continue
        if c == "/" and i + 1 < n:
            if raw[i + 1] == "/":
                while i < n and raw[i] != "\n":
                    i += 1
                continue
            if raw[i + 1] == "*":
                end = raw.find("*/", i + 2)
                i = n if end == -1 else end + 2
                continue
        out.append(c)
        i += 1
    return "".join(out)

def _read_jsonc(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError:
        return None
    raw = TRAILING_COMMA.sub(r"\1", _strip_jsonc_comments(raw))
    try:
        return json.loads(raw)
    except ValueError:
        return None

def _mnm_rules(mapper, root):
    out, skipped = [], 0
    for key, val in mapper.items():
        if not isinstance(val, str):
            skipped += 1
            continue
        m = MNM_SHAPES[0].match(key) or MNM_SHAPES[1].match(key)
        if not m:
            skipped += 1
            continue
        pfx = m.group("pfx")
        tgt = val.replace("<rootDir>/", "").replace("<rootDir>", "")
        wild = MNM_SHAPES[0].match(key) is not None
        if wild:
            if "$1" not in tgt:
                skipped += 1
                continue
            tmpl = tgt.replace("$1", "*").replace("//", "/").rstrip("/")
            if "*" not in tmpl:
                skipped += 1
                continue
            out.append((pfx + "/", "", [tmpl]))
        else:
            if "$" in tgt:
                skipped += 1
                continue
            out.append((pfx, "", [tgt]))
    return out, skipped

def package_json_aliases(root):
    pj = os.path.join(root, "package.json")
    cfg = _read_jsonc(pj)
    if not isinstance(cfg, dict):
        return [], 0
    jest = cfg.get("jest")
    if not isinstance(jest, dict):
        return [], 0
    mapper = jest.get("moduleNameMapper")
    if not isinstance(mapper, dict):
        return [], 0
    return _mnm_rules(mapper, root)

def _extends_files(cfg, cfg_file, root):
    ext = cfg.get("extends")
    if isinstance(ext, str):
        ext = [ext]
    if not isinstance(ext, list):
        return []
    here = os.path.dirname(cfg_file)
    out = []
    for e in ext:
        if not isinstance(e, str) or not e:
            continue
        if e.startswith((".", "/")):
            c = os.path.normpath(os.path.join(here, e))
            cands = [c] if c.endswith(".json") else [c + ".json", c, os.path.join(c, "tsconfig.json")]
        else:
            cands, d = [], here
            while True:
                b = os.path.join(d, "node_modules", e)
                cands += [b, b + ".json", os.path.join(b, "tsconfig.json")]
                if d == root or os.path.dirname(d) == d:
                    break
                d = os.path.dirname(d)
        for c in cands:
            if os.path.isfile(c):
                out.append(c)
                break
    return out

def _effective(cfg_file, root, _depth=0):
    if _depth > 6:
        return {}
    cfg = _read_jsonc(cfg_file)
    if not isinstance(cfg, dict):
        return {}
    eff = {}
    for parent in _extends_files(cfg, cfg_file, root):
        eff.update(_effective(parent, root, _depth + 1))
    here = os.path.dirname(cfg_file)
    co = cfg.get("compilerOptions")
    if isinstance(co, dict):
        for key in ("baseUrl", "outDir", "rootDir", "declarationDir"):
            if isinstance(co.get(key), str):
                eff[key] = os.path.normpath(os.path.join(here, co[key]))
        for key in ("jsx", "module", "moduleResolution", "target", "allowJs"):
            if isinstance(co.get(key), (str, bool)):
                eff["opt:" + key] = co[key]
        if isinstance(co.get("paths"), dict):
            eff["paths"], eff["paths_dir"] = co["paths"], here
    inc = cfg.get("include")
    if isinstance(inc, list):
        eff["include"] = [os.path.normpath(os.path.join(here, i)) for i in inc if isinstance(i, str)]
    if isinstance(cfg.get("references"), list):
        eff["references"] = [(here, r.get("path")) for r in cfg["references"]
                             if isinstance(r, dict) and isinstance(r.get("path"), str)]
    else:
        eff.pop("references", None)
    return eff

def _paths_rules(paths, base_dir, root):
    rules = []
    for key, targets in paths.items():
        if not isinstance(targets, list) or key.count("*") > 1:
            continue
        pre, _, suf = key.partition("*")
        tmpl = []
        for t in targets:
            if not isinstance(t, str) or t.count("*") > 1:
                continue
            r = os.path.relpath(os.path.normpath(os.path.join(base_dir, t)), root).replace(os.sep, "/")
            if not r.startswith(".."):
                tmpl.append(r)
        if tmpl:
            rules.append((pre, suf, tmpl))
    return rules

def _rel_or_none(abs_path, root):
    r = os.path.relpath(abs_path, root).replace(os.sep, "/")
    if r.startswith(".."):
        return None
    return "" if r == "." else r

def config_rules(cfg_file, root):
    eff = _effective(cfg_file, root)
    rules, base = [], None
    if isinstance(eff.get("paths"), dict):
        rules = _paths_rules(eff["paths"], eff.get("baseUrl") or eff["paths_dir"], root)
    if eff.get("baseUrl"):
        base = _rel_or_none(eff["baseUrl"], root)
    if not rules:
        for here, ref in eff.get("references", []):
            c = os.path.normpath(os.path.join(here, ref))
            if not c.endswith(".json"):
                c = os.path.join(c, "tsconfig.json")
            if os.path.dirname(c) != os.path.dirname(cfg_file) or c == cfg_file:
                continue
            if os.path.isfile(c):
                r2, b2 = config_rules(c, root)
                rules.extend(r2)
                base = base if base is not None else b2
    return rules, base

def apply_aliases(spec, aliases):
    out = []
    for pre, suf, targets in aliases:
        if not spec.startswith(pre) or not spec.endswith(suf):
            continue
        if len(spec) < len(pre) + len(suf):
            continue
        star = spec[len(pre):len(spec) - len(suf)] if (pre or suf) else spec
        for t in targets:
            out.append(t.replace("*", star) if "*" in t else t)
        if out:
            break
    return out

def workspace_globs(root):
    globs = []
    pj = _read_jsonc(os.path.join(root, "package.json"))
    ws = pj.get("workspaces") if isinstance(pj, dict) else None
    if isinstance(ws, dict):
        ws = ws.get("packages")
    if isinstance(ws, list):
        globs += [g for g in ws if isinstance(g, str)]
    lerna = _read_jsonc(os.path.join(root, "lerna.json"))
    if isinstance(lerna, dict) and isinstance(lerna.get("packages"), list):
        globs += [g for g in lerna["packages"] if isinstance(g, str)]
    try:
        with open(os.path.join(root, "pnpm-workspace.yaml"), encoding="utf-8", errors="replace") as fh:
            text = fh.read(200000)
    except OSError:
        text = ""
    inside = False
    for line in text.splitlines():
        if re.match(r'^packages:\s*$', line):
            inside = True
            continue
        if inside:
            m = re.match(r'''^\s+-\s*['"]?([^'"#\s]+)['"]?\s*(#.*)?$''', line)
            if m:
                globs.append(m.group(1))
            elif line.strip() and not line.startswith((" ", "\t", "#")):
                inside = False
    return globs

def _out_root_pairs(pkg_abs, root):
    pairs = []
    try:
        names = sorted(n for n in os.listdir(pkg_abs) if re.match(r'^tsconfig.*\.json$', n))
    except OSError:
        return pairs
    for n in names:
        eff = _effective(os.path.join(pkg_abs, n), root)
        rd = eff.get("rootDir")
        if rd is None and eff.get("include"):
            heads = {re.split(r'[*{]', i)[0].rstrip("/") for i in eff["include"]}
            if len(heads) == 1:
                rd = heads.pop()
        if rd is None:
            continue
        for key in ("outDir", "declarationDir"):
            o = eff.get(key)
            if o:
                ro, rr = _rel_or_none(o, root), _rel_or_none(rd, root)
                if ro and rr is not None and (ro, rr) not in pairs:
                    pairs.append((ro, rr))
    pairs.sort(key=lambda p: len(p[0]), reverse=True)
    return pairs

def _export_leaves(v, star=None, _depth=0):
    if _depth > 8 or v is None:
        return []
    if isinstance(v, str):
        return [v.replace("*", star) if star is not None else v]
    out = []
    if isinstance(v, list):
        for x in v:
            out += _export_leaves(x, star, _depth + 1)
    elif isinstance(v, dict):
        keys = [k for k in EXPORT_CONDITIONS if k in v] + [k for k in v if k not in EXPORT_CONDITIONS]
        for k in keys:
            out += _export_leaves(v[k], star, _depth + 1)
    return out

def _match_exports(exports, sub):
    if isinstance(exports, (str, list)) or (
            isinstance(exports, dict) and not any(k.startswith(".") for k in exports)):
        exports = {".": exports}
    if not isinstance(exports, dict):
        return []
    if sub in exports:
        return _export_leaves(exports[sub])
    best = None
    for k in exports:
        if k.count("*") != 1:
            continue
        pre, _, suf = k.partition("*")
        if sub.startswith(pre) and sub.endswith(suf) and len(sub) >= len(pre) + len(suf):
            if best is None or len(pre) > len(best[0]):
                best = (pre, suf, k)
    if best:
        return _export_leaves(exports[best[2]], sub[len(best[0]):len(sub) - len(best[1])])
    return []

def workspace_bases(spec, pkgs):
    name = None
    for n in pkgs:
        if spec == n or spec.startswith(n + "/"):
            if name is None or len(n) > len(name):
                name = n
    if name is None:
        return False, []
    pkg = pkgs[name]
    sub = "." if spec == name else "./" + spec[len(name) + 1:]
    if pkg["exports"] is not None:
        leaves = _match_exports(pkg["exports"], sub)
    elif sub == ".":
        leaves = pkg["entries"] + ["index"]
    else:
        leaves = [sub]
    out = []
    for leaf in leaves:
        p = os.path.normpath(os.path.join(pkg["dir"], leaf)).replace(os.sep, "/")
        if p.startswith(".."):
            continue
        stripped = p
        for e in BUILD_EXT:
            if p.endswith(e):
                stripped = p[:-len(e)]
                break
        out.append(p)
        for o, r in pkg["outmap"]:
            if stripped == o or stripped.startswith(o + "/"):
                out.append((r + stripped[len(o):]).lstrip("/"))
                break
        out.append(stripped)
    return True, out


# ---- END shared ----------------------------------------------------------------------------


class _Pkg(dict):
    """A workspace member whose outDir->rootDir map is read only when a specifier names it."""
    def __init__(self, root, rel, pj):
        dict.__init__(self, dir=rel, exports=pj.get("exports"),
                      entries=[pj[k] for k in ("types", "typings", "module", "main")
                               if isinstance(pj.get(k), str)])
        self._root = root

    def __getitem__(self, key):
        if key == "outmap" and not dict.__contains__(self, key):
            dict.__setitem__(self, key, _out_root_pairs(os.path.join(self._root, self["dir"]), self._root))
        return dict.__getitem__(self, key)


def _member_dirs(root, g):
    """glob for a plain pattern; for `**` a walk that never enters PRUNE or dot dirs (glob would
    descend node_modules, on every write, only to discard what it found there)."""
    if "**" not in g:
        return _glob.glob(os.path.join(root, g.rstrip("/")))
    lit = []
    for seg in g.split("/"):
        if any(c in seg for c in "*?["):
            break
        lit.append(seg)
    out = []
    for dp, dn, _ in os.walk(os.path.join(root, *lit)):
        dn[:] = sorted(d for d in dn if d not in PRUNE and not d.startswith("."))
        rel = os.path.relpath(dp, root).replace(os.sep, "/")
        if fnmatch(rel, g.rstrip("/")):
            out.append(dp)
    return out


def workspace_packages(root):
    """rank-source-files.py's workspace_packages(), with a pruned `**` walk and a lazy outmap."""
    dirs = set()
    for g in workspace_globs(root):
        if g.startswith("!"):
            continue
        for d in _member_dirs(root, g):
            rel = _rel_or_none(d, root)
            if rel is None or not os.path.isfile(os.path.join(d, "package.json")):
                continue
            if any(seg in PRUNE for seg in rel.split("/")):
                continue
            dirs.add(rel)
    pkgs = {}
    for rel in sorted(dirs):
        pj = _read_jsonc(os.path.join(root, rel, "package.json"))
        if not isinstance(pj, dict) or not isinstance(pj.get("name"), str):
            continue
        pkgs[pj["name"]] = _Pkg(root, rel, pj)
    return pkgs


def scope_rules(root, d):
    """The alias rules governing files in repo-relative dir `d`: the nearest tsconfig.json /
    jsconfig.json at or above it (tsconfig.base.json too at the root), merged with that
    directory's package.json jest.moduleNameMapper; a scope that declares nothing falls through
    to the next one up. rank-source-files.py's Resolver scopes, walked for ONE file's ancestors
    instead of the whole tree."""
    while True:
        segs = d.split("/") if d else []
        if not any(s in PRUNE or s.startswith(".") for s in segs):
            rules = []
            for name in (ROOT_CONFIG_NAMES if not d else CONFIG_NAMES):
                cand = os.path.join(root, d, name)
                if os.path.isfile(cand):
                    rules = config_rules(cand, root)[0]
                    break
            if os.path.isfile(os.path.join(root, d, "package.json")):
                mnm, _ = package_json_aliases(os.path.join(root, d))
                prefix = (d + "/") if d else ""
                rules = rules + [(p, s, [prefix + t for t in ts]) for p, s, ts in mnm]
            if rules:
                return sorted(rules, key=lambda x: len(x[0]), reverse=True)
        if not d:
            return []
        d = os.path.dirname(d)


def on_disk(root, bases):
    """The first candidate that is a real source file outside build output — the same candidate
    order rank-source-files.py tries against its file index. None when nothing exists."""
    for cand in bases:
        stem, ext = os.path.splitext(cand)
        cands = [cand] if ext in SOURCE_EXT else []
        cands += [stem + e for e in JS_TO_TS.get(ext, ())]
        for e in TS_EXT + SFC_EXT:
            cands += [cand + e, cand + "/index" + e]
        for c in cands:
            c = c.lstrip("./")
            if any(s in PRUNE or s.startswith(".") for s in c.split("/")[:-1]):
                continue
            if os.path.isfile(os.path.join(root, c)):
                return c
    return None


root = os.path.abspath(".")
here = os.path.dirname(os.environ.get("MB_FILE", "")).strip("/")
rules = scope_rules(root, "" if here == "." else here)
pkgs = None
for spec in os.environ.get("MB_SPECS", "").split("\n"):
    if not spec or spec.startswith(".") or "\t" in spec:
        continue
    # A `paths` entry wins and its FIRST target is taken without touching the disk, as before.
    hit = apply_aliases(spec, rules)
    tgt = hit[0] if hit else None
    if tgt is None:
        if pkgs is None:
            pkgs = workspace_packages(root)
        ok, bases = workspace_bases(spec, pkgs)
        tgt = on_disk(root, bases) if ok else None
    if tgt and "\t" not in tgt and "\n" not in tgt:
        sys.stdout.write("%s\t%s\n" % (spec, tgt))
PYEOF
  RESOLVED=$(MB_FILE="$rel_path" MB_SPECS="$nonrel" python3 -I -c "$PYSRC" 2>/dev/null || true)
fi

resolve() {  # specifier → normalised repo path, or empty when unresolvable
  local s="$1" a=""
  # Dart first: its specifier grammar shares no shape with the TS one below. A bare
  # `models/x.dart` is relative to the importing FILE in Dart, not rooted at a source dir —
  # treating it as rooted would aim the boundary check at a different file and could refuse a
  # legitimate write, which is the one failure this hook must not have.
  case "$file_path" in
    (*.dart)
      case "$s" in
        dart:*) printf '' ;;
        "package:$DART_PKG/"*)
          [ -n "$DART_PKG" ] && norm "lib/${s#package:$DART_PKG/}" || printf '' ;;
        package:*) printf '' ;;                 # a dependency, not a file in this repo
        *) canon "$dir_of_file/$s" | sed 's|^src/||; s|^app/||; s|^lib/||' ;;
      esac
      return 0 ;;
  esac
  # The config table first (then a workspace package), and only for non-relative specifiers: a
  # relative path is already unambiguous, and no `paths` key may override it. When several
  # targets share a key the FIRST is taken, matching the order tsc tries them. That can only ever
  # under-resolve, which for a hook that blocks writes is the safe direction to be wrong in.
  case "$s" in
    ./*|../*) ;;
    *) [ -n "$RESOLVED" ] && \
         a=$(printf '%s\n' "$RESOLVED" | awk -F'\t' -v s="$s" '$1 == s { print $2; exit }') ;;
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

# Every specifier is resolved ONCE, here, not once per rule: resolve() forks, and the old
# rules × specifiers product cost seconds on a full-file Write with a few rules declared.
SPEC_TABLE=$(for s in $specs; do r=$(resolve "$s"); [ -n "$r" ] && printf '%s\t%s\n' "$s" "$r"; done)
[ -z "$SPEC_TABLE" ] && exit 0

while IFS= read -r rule; do
  [ -n "$rule" ] || continue
  ln=${rule%%"$TAB"*}; rest=${rule#*"$TAB"}; scope=${rest%%"$TAB"*}; body=${rest#*"$TAB"}
  [ -z "$scope" ] || [ "$scope" = "$SELF_ROOT" ] || continue   # a rule for another section
  case "$body" in *"\`$SELF\`"*) ;; *) continue ;; esac   # its subject cannot be this module
  a=$(printf '%s' "$body" | grep -oE '`[^`]+`' | sed -n '1p' | tr -d '`')
  b=$(printf '%s' "$body" | grep -oE '`[^`]+`' | sed -n '2p' | tr -d '`')
  [ -n "$a" ] && [ -n "$b" ] || continue
  [ "$a" = "$SELF" ] || continue

  b_path=$(path_of "$b" "$scope" "$SELF_ROOT") || continue
  [ -n "$b_path" ] || continue

  case "$body" in
    *"MUST NOT"*)
      while IFS="$TAB" read -r s r; do
        [ -n "$r" ] || continue
        case "$r/" in
          "$b_path"/*)
            block "\`$SELF\` MUST NOT import from \`$b\` — $rel_path imports '$s' (ai/modules.md:$ln)" ;;
        esac
      done <<SPECEOF
$SPEC_TABLE
SPECEOF
      ;;
    *MAY*only\ via*)
      facade=$(printf '%s' "$body" | grep -oE '`[^`]+`' | sed -n '3p' | tr -d '`')
      [ -n "$facade" ] || continue
      f_path=$(norm "$facade")
      # A declared facade is written the way a human writes a FILE — `libs/shared/src/index.ts`.
      # An import is written the way TypeScript/JS require — no extension, and a directory when the
      # target is its index. Comparing the two literally rejects the one path the rule permits, so
      # both sides are compared extension-free, and an `index` facade also answers to its directory.
      f_base=$(printf '%s' "$f_path" | sed -E 's/\.(ts|tsx|js|jsx|mjs|cjs|py|vue|svelte|dart)$//')
      f_dir=""
      case "$f_base" in */index) f_dir="${f_base%/index}" ;; esac
      while IFS="$TAB" read -r s r; do
        [ -n "$r" ] || continue
        case "$r/" in
          "$b_path"/*)
            r_base=$(printf '%s' "$r" | sed -E 's/\.(ts|tsx|js|jsx|mjs|cjs|py)$//')
            case "$r_base" in
              "$f_base"|"$f_base"/*|*"/$f_base") continue ;;
            esac
            [ -n "$f_dir" ] && [ "$r_base" = "$f_dir" ] && continue
            block "\`$SELF\` may reach \`$b\` only via \`$facade\` — $rel_path imports '$s' directly (ai/modules.md:$ln)" ;;
        esac
      done <<SPECEOF2
$SPEC_TABLE
SPECEOF2
      ;;
  esac
done <<RULEEOF
$RULES
RULEEOF

exit 0

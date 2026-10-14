#!/usr/bin/env python3
"""rank-source-files.py — order a repo's source files by how much they teach about it.

WHY THIS EXISTS. `extract-codebase-overview` caps its walk on a large repo, and the cap it
declared was "cap walk depth to 4; sample by file count". Depth in the directory tree is a
TOPOLOGICAL ACCIDENT: it measures how deeply someone nested a folder, not how much the file
matters. In a workspace laid out `packages/<pkg>/src/modules/<m>/service.ts` every service is at
depth 5 and the whole layer is dropped, while a top-level `scripts/` folder is kept in full. The
sample was disclosed honestly — `[SAMPLED: <seen>/<present>]` and check 7 see to that — but an
honestly-reported bad sample is still a bad sample.

What a reader actually wants, given a budget of N files out of 12,000, is the N that the rest of
the codebase is built on. That is computable, exactly and cheaply, from imports the files already
declare. No model, no embedding, no heuristic about names.

THE TWO KINDS, and why one ranking is not enough. Ranking purely by "most imported" surfaces
shared abstractions and buries every entry point, because a route file, a CLI command and a job
handler are imported by nothing — they are where the program STARTS, and they describe the
system's surface better than any util does. So files are ranked in two bands:

    hub    imported by others. Rank: distinct importing DIRECTORIES first, then importer count.
           Directories first is the point: a file pulled in by 40 files from one folder is a
           local helper; one pulled in by 12 files from 9 folders is load-bearing.
    root   imports others, imported by none. Rank: number of distinct modules it reaches.

With --limit, the budget splits 75/25 hub/root. The split is a judgement, stated here so it can
be argued with, and printed in the header so a reader knows what they got.

HONEST LIMITS — read these before trusting the order:
  * TypeScript / JavaScript and Python only. Any other extension is NOT walked and does not
    appear in the census at all — so on a Go or Java repo `present` reads 0 and the ranking is
    empty rather than wrong. This tool does not pretend to parse a language it cannot, and it
    does not pretend to have counted one either.
  * A specifier that does not resolve to a file in the repo is dropped, not guessed. What IS
    read, all of it data on disk: every tsconfig/jsconfig `paths` + `baseUrl` (scoped to its own
    directory, `extends` followed, same-dir `references` read), jest `moduleNameMapper`, the
    workspace member list (pnpm-workspace.yaml / package.json `workspaces` / lerna.json) and each
    member's `exports` / `main` / `types`, mapped from build output back to source through that
    package's own outDir -> rootDir. Aliases declared only in JS (vite/webpack) and generated
    barrels contribute nothing. The drop count is split external / asset / local; a LOCAL miss
    is the one that means a blind spot. Under-counting is the intended failure direction: it
    demotes a file, it never invents importance.
  * `in_degree` counts static imports only. A file reached solely through DI, a registry, or a
    string-keyed dynamic require looks isolated here and will rank low. That is a real blind
    spot, not a rounding error.

Usage:
  rank-source-files.py <repo> [--limit N] [--format table|list|json] [--include-tests]

Exit: 0 ok · 2 usage error.
"""

import argparse
import json
import os
import re
import sys

TS_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".mts", ".cts")
PY_EXT = (".py",)
# A single-file component holds its imports inside a <script> block, so it is a TS file wearing a
# different extension — the ONE difference is that the block has to be cut out first (a template
# or a <style> can contain text that looks like an import). Left out, a Vue or Svelte app loses
# most of its own files: `.ts` alone covered 256 of 594 files on the first real frontend tried.
SFC_EXT = (".vue", ".svelte")
# Dart has its own specifier grammar (`package:<self>/x.dart`), resolved against pubspec's `name`.
DART_EXT = (".dart",)
SOURCE_EXT = TS_EXT + PY_EXT + SFC_EXT + DART_EXT
PRUNE = {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build", ".next",
         ".mypy_cache", ".pytest_cache", "vendor", "target", ".tox", "coverage"}
TEST_HINT = re.compile(r'(^|/)(tests?|__tests__|spec)(/|$)|\.(test|spec)\.[a-z]+$|(^|/)test_[^/]+\.py$')

TS_IMPORT = re.compile(r"""(?:^|[\s;{(=])(?:import|export)\s[^'"]*?from\s*['"]([^'"]+)['"]"""
                       r"""|(?:^|[\s;{(=])import\s*['"]([^'"]+)['"]"""
                       r"""|\brequire\s*\(\s*['"]([^'"]+)['"]\s*\)"""
                       r"""|\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)""", re.M)
PY_IMPORT = re.compile(r'^[ \t]*(?:from[ \t]+([.\w]+)[ \t]+import|import[ \t]+([.\w]+))', re.M)
# `part` is included: it is how a Dart library is split across files, and the generated half
# (`*.g.dart`, `*.freezed.dart`) is a real dependency that breaks when the declaring file moves.
DART_IMPORT = re.compile(r"""^[ \t]*(?:import|export|part)[ \t]+['"]([^'"]+)['"]""", re.M)
SFC_SCRIPT = re.compile(r'<script\b[^>]*>(.*?)</script\s*>', re.S | re.I)


def walk(root, include_tests):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in PRUNE and not d.startswith("."))
        for name in sorted(filenames):
            if not name.endswith(SOURCE_EXT):
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), root).replace(os.sep, "/")
            if not include_tests and TEST_HINT.search(rel):
                continue
            out.append(rel)
    return out


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def specifiers(rel, text):
    return [s for s, _ in specifier_kinds(rel, text)]


# Statement-level type-only erasure. `import type …`, `export type … from`, and a braced clause
# whose EVERY item is `type X` are erased by the compiler — they never run, so they cannot close a
# runtime cycle. A clause with one value item (or a default / namespace binding) is a value import.
# `import()` is dynamic: it runs, but not at module init, so it does not close an init-order cycle
# either. An EDGE is type-only only when every statement behind it is (dependency-cruiser's rule
# too): one value import of a file that is also re-exported as a type keeps the edge a value.
TS_CLAUSE = re.compile(r"""[\s;{(=]?(?:import|export)\s+(type\s+(?!from\b))?(.*?)\s*from\s*['"]""", re.S)
TYPE_ITEM = re.compile(r'^type\s')
TS_BLOCK_COMMENT = re.compile(r'^[ \t]*/\*.*?\*/', re.S | re.M)
TS_LINE_COMMENT = re.compile(r'^[ \t]*//[^\n]*', re.M)


def _ts_statement_kind(m):
    if m.group(4):
        return "dynamic"
    if not m.group(1):
        return "value"                    # bare `import 'x'` and require() both run
    mm = TS_CLAUSE.match(m.group(0))
    if not mm:
        return "value"
    if mm.group(1):
        return "type"
    clause = mm.group(2)
    braced = re.search(r'\{([^}]*)\}', clause)
    outside = re.sub(r'\{[^}]*\}', ' ', clause).replace(",", " ").split()
    if braced and not outside:
        items = [x.strip() for x in braced.group(1).split(",") if x.strip()]
        if items and all(TYPE_ITEM.match(x) for x in items):
            return "type"
    return "value"


def specifier_kinds(rel, text):
    """[(specifier, 'value' | 'type' | 'dynamic')] in source order."""
    if rel.endswith(PY_EXT):
        return [(a or b, "value") for a, b in PY_IMPORT.findall(text) if (a or b)]
    if rel.endswith(DART_EXT):
        return [(x, "value") for x in DART_IMPORT.findall(text)]
    if rel.endswith(SFC_EXT):
        # Only the <script> blocks. Scanning the whole SFC would read `@import` in <style> and any
        # string in the template as a specifier, and a wrong edge is worse than a missing one.
        text = "\n".join(SFC_SCRIPT.findall(text))
    # A comment is not an import. A JSDoc `@import import { X } from '@/x'` line closed two
    # phantom value cycles on a real React app; only comments that START a line are cut, so a
    # `'src/**/*.ts'` string can never open a "block" that swallows real imports after it.
    text = TS_LINE_COMMENT.sub("", TS_BLOCK_COMMENT.sub("", text))
    return [(next(g for g in m.groups() if g), _ts_statement_kind(m))
            for m in TS_IMPORT.finditer(text)]


# A tsconfig/jsconfig `paths` entry RENAMES rather than shortens (`@app/database/*` ->
# `libs/database/src/*`), so no sigil rule can resolve it — the mapping exists only in the config
# file. Reading that file is deterministic: it is the same table the compiler and bundler use. When
# it is missing, unparseable, or has no `paths`, aliases stay empty and resolution behaves exactly
# as it did before — silent, never inventing a target.
TRAILING_COMMA = re.compile(r',(\s*[}\]])')


def _strip_jsonc_comments(raw):
    """Remove // and /* */ comments, skipping over string literals.

    This is a scanner and not a regex on purpose. A regex cannot know it is inside a string, and
    the alias table is written `"paths": { "@/*": ["src/*"] }` — the `/*` in that key opened a
    block comment that ran to the next real `*/` in the file and swallowed the whole
    compilerOptions object. Every tsconfig that has BOTH a `paths` entry and a block comment (the
    stock Vite/Vue/React template has both) parsed as invalid JSON and silently yielded zero alias
    rules, which reads downstream as "this project declares no aliases".
    """
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
        return None                       # unparseable is not a licence to guess


# Jest's moduleNameMapper is a REGEX table, not a glob one, so only the shapes that convert
# EXACTLY are taken. Anything else is left to alias_blind_spots() to disclose. Guessing at a
# regex is how a resolver starts inventing edges.
MNM_SHAPES = (
    # ^pfx(|/.*)$ -> tgt/$1   and   ^pfx/(.*)$ -> tgt/$1   and   ^pfx$ -> tgt
    re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)/?\(\|?/?\.\*\)\$$'),
    re.compile(r'^\^(?P<pfx>[^()\[\]{}|+?*\\^$]+?)\$$'),
)


def _mnm_rules(mapper, root):
    """moduleNameMapper -> the same (prefix, suffix, target) rules, for exactly-convertible keys."""
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
            # `tgt/$1` is the only replacement shape that round-trips to a `*` template.
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
    """jest.moduleNameMapper from package.json — JSON, so parseable without executing anything."""
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


# Config files that DECLARE aliases in JavaScript. Reading them would mean executing JS or
# shipping a JS parser; a regex scrape would be a guess, and a guessed alias in the boundary hook
# refuses legitimate writes. So they are DETECTED and REPORTED, never parsed. A disclosed blind
# spot can be worked around; a silent one cannot.
JS_ALIAS_CONFIGS = ("vite.config.ts", "vite.config.js", "vite.config.mjs",
                    "webpack.config.js", "webpack.config.ts", "rollup.config.js",
                    "jest.config.js", "jest.config.ts", "next.config.js", "craco.config.js")
JS_ALIAS_HINT = re.compile(r'\balias\b|moduleNameMapper')


# FILE-BASED ROUTING. A Nuxt page, a Next route, a SvelteKit +page — nothing imports it; the
# FRAMEWORK reaches it by its path. Measured on a real Nuxt storefront: 19 of 19 files under
# pages/ and 7 of 8 under server/ had zero importers, and every one of those zeroes was correct.
# The danger is not the count, it is how the count READS: `--who-breaks pages/checkout.vue`
# returning nothing looks exactly like "nothing depends on this" when it means "the router does,
# and the router is not an import". Same for a component used only in a `<template>` under Nuxt's
# auto-import — the SFC's <script> block holds no specifier for it, by design.
#
# Disclosed, never inferred: the check needs BOTH a framework config on disk AND the directory
# that framework routes from, and it reports directories it actually found.
ROUTED_FRAMEWORKS = (
    ("nuxt", ("nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs"),
     ("pages", "server/api", "server/routes", "layouts", "middleware")),
    ("next", ("next.config.js", "next.config.ts", "next.config.mjs"),
     ("pages", "app", "src/pages", "src/app")),
    ("sveltekit", ("svelte.config.js", "svelte.config.ts"), ("src/routes",)),
    ("remix", ("remix.config.js", "remix.config.ts"), ("app/routes",)),
)


def routed_blind_spots(root, pkg_dirs=("",)):
    """[(framework, [dirs])] for every package dir (the root, and each workspace app) a
    file-based router owns — [] when none. In a monorepo the Next app is apps/web, not the root."""
    out = []
    for pd in sorted(pkg_dirs):
        base = os.path.join(root, pd)
        for name, configs, dirs in ROUTED_FRAMEWORKS:
            if not any(os.path.isfile(os.path.join(base, c)) for c in configs):
                continue
            found = [(pd + "/" + d) if pd else d for d in dirs if os.path.isdir(os.path.join(base, d))]
            if found:
                out.append((name, found))
                break
    return out


def alias_blind_spots(root, pkg_dirs=("",)):
    """Config files that look like they declare aliases and that nothing here can read."""
    out = []
    for pd in sorted(pkg_dirs):
        for name in JS_ALIAS_CONFIGS:
            p = os.path.join(root, pd, name)
            if not os.path.isfile(p):
                continue
            try:
                with open(p, encoding="utf-8", errors="replace") as fh:
                    if JS_ALIAS_HINT.search(fh.read(200000)):
                        out.append((pd + "/" + name) if pd else name)
            except OSError:
                continue
    return out


def dart_package_name(root):
    """pubspec.yaml's `name:` — the only thing that tells `package:x/y.dart` apart from a
    third-party package. No YAML parser is needed or wanted: `name` is a top-level scalar, and a
    regex that only accepts a column-0 key cannot be fooled by a nested one."""
    try:
        with open(os.path.join(root, "pubspec.yaml"), encoding="utf-8", errors="replace") as fh:
            m = re.search(r'^name:[ \t]*["\']?([A-Za-z_][A-Za-z0-9_]*)', fh.read(200000), re.M)
    except OSError:
        return None
    return m.group(1) if m else None


# ---------------------------------------------------------------- tsconfig `paths`, per scope
#
# ONE table for the whole repo was the shape of a real miss: a pnpm/turbo monorepo keeps shared
# compiler options in tsconfig.base.json (no `paths` at all) and each app's own tsconfig.json
# carries that app's table (`apps/web/tsconfig.json: "@/*": ["src/*"]`). Reading only
# <root>/tsconfig.json read 0 alias rules on a real NestJS + React monorepo and left 21,101
# specifiers unresolved (2026-10-15). TypeScript resolves a file with the config that includes
# it, so the rules are SCOPED: every tsconfig.json / jsconfig.json under the repo governs the
# files below its directory, nearest first. A nearest config that declares nothing (no `paths`,
# no `baseUrl`) falls through to the next one up, which is the old single-table behaviour.

CONFIG_NAMES = ("tsconfig.json", "jsconfig.json")
# At the root a monorepo often has no tsconfig.json at all, only the base the apps extend.
ROOT_CONFIG_NAMES = ("tsconfig.json", "jsconfig.json", "tsconfig.base.json")


def _extends_files(cfg, cfg_file, root):
    """The config files `extends` names (string or, since TS 5.0, a list), in order. A package
    name is followed only when it is installed — a base that is not on disk is not guessed at."""
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
    """The options this script needs, after `extends`, by TypeScript's merge rule.

    A child's `paths` REPLACES its parent's (it never merges); `baseUrl`, `outDir`, `rootDir`
    and `declarationDir` resolve against the config that DECLARED them; with no `baseUrl`,
    `paths` targets resolve against the config that declared `paths` (TS 4.1+); `include`
    resolves against its own declaring config. Returns {} when the file cannot be parsed.
    """
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
                eff["opt:" + key] = co[key]       # carried into --ts-wrapper only
        if isinstance(co.get("paths"), dict):
            eff["paths"], eff["paths_dir"] = co["paths"], here
    inc = cfg.get("include")
    if isinstance(inc, list):
        eff["include"] = [os.path.normpath(os.path.join(here, i)) for i in inc if isinstance(i, str)]
    if isinstance(cfg.get("references"), list):
        eff["references"] = [(here, r.get("path")) for r in cfg["references"]
                             if isinstance(r, dict) and isinstance(r.get("path"), str)]
    else:
        eff.pop("references", None)        # references are never inherited
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
    """(rules, baseUrl repo-relative or None) for ONE config file, `extends` followed.

    A solution-style tsconfig.json (`"files": []` + `references`, the stock Vite template) keeps
    its table in tsconfig.app.json; a reference that lives in the SAME directory is read in its
    place. A reference into another directory is that directory's scope, not this one's.
    """
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


def path_aliases(root, _depth=0, _file=None):
    """[(prefix, suffix, [target templates])] for the ROOT scope, longest first: the root
    tsconfig/jsconfig (else tsconfig.base.json), `extends` followed, plus package.json's jest
    moduleNameMapper. Kept for callers that want one table; resolution uses Resolver."""
    rules = []
    for name in ROOT_CONFIG_NAMES:
        cand = os.path.join(root, name)
        if os.path.isfile(cand):
            rules = config_rules(cand, root)[0]
            break
    # No tsconfig is not "no aliases": a project can declare them only in package.json's jest
    # block. Returning [] there made that table unreachable, which the fixture caught.
    rules.extend(package_json_aliases(root)[0])
    rules.sort(key=lambda r: len(r[0]), reverse=True)  # longest literal prefix wins, as in tsc
    return rules


def apply_aliases(spec, aliases):
    """Every repo-relative base path `spec` could name under `paths`. Empty when none matches."""
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
            break                          # first (longest) matching rule wins, as tsc does
    return out


# ---------------------------------------------------------------- workspace packages
#
# `@scope/contracts/orders` is a workspace package, not npm — but nothing in a tsconfig says so.
# The package manager's workspace list says which directories are packages; each package.json's
# `exports` (else main/types) says which file a subpath names; and that file is usually BUILD
# OUTPUT (`./dist/orders/index.d.ts`), which the package's own tsconfig maps back to source
# through outDir -> rootDir. All three are data on disk. Measured on the same monorepo: 1 edge
# into packages/ before, against 1,669 import lines naming the contracts package.

# Condition order: the one most likely to name a source or declaration file first. Every leaf
# is TRIED (first that resolves wins), so the order decides ties, never whether an edge exists.
EXPORT_CONDITIONS = ("source", "types", "typings", "import", "module", "require", "node",
                     "browser", "development", "production", "default")
BUILD_EXT = (".d.ts", ".d.mts", ".d.cts", ".js", ".mjs", ".cjs", ".jsx")


def workspace_globs(root):
    """Member globs from pnpm-workspace.yaml, package.json `workspaces`, and lerna.json."""
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
    """(outDir, rootDir) pairs, repo-relative, from every tsconfig*.json in the package dir."""
    pairs = []
    try:
        names = sorted(n for n in os.listdir(pkg_abs) if re.match(r'^tsconfig.*\.json$', n))
    except OSError:
        return pairs
    for n in names:
        eff = _effective(os.path.join(pkg_abs, n), root)
        rd = eff.get("rootDir")
        if rd is None and eff.get("include"):
            # tsc's implied rootDir is the common root of the inputs; `include: ["src/**/*"]`
            # makes that src/. Only a single literal leading directory is taken.
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


def workspace_packages(root):
    """{package name: {dir, exports, entries, outmap}} for every declared workspace member."""
    import glob as _glob
    dirs = set()
    for g in workspace_globs(root):
        if g.startswith("!"):
            continue
        for d in _glob.glob(os.path.join(root, g.rstrip("/")), recursive=True):
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
        pkgs[pj["name"]] = {
            "dir": rel,
            "exports": pj.get("exports"),
            "entries": [pj[k] for k in ("types", "typings", "module", "main")
                        if isinstance(pj.get(k), str)],
            "outmap": _out_root_pairs(os.path.join(root, rel), root),
        }
    return pkgs


def _export_leaves(v, star=None, _depth=0):
    """Every target string under an `exports` value, preferred conditions first."""
    if _depth > 8 or v is None:
        return []                       # null blocks the subpath: no edge, by the package's say
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
    """The leaves `exports` maps subpath `sub` ('.' or './x') to; [] when it maps nothing."""
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
    """(matched, [repo-relative base paths]) for a specifier naming a workspace package."""
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


# ---------------------------------------------------------------- resolution

# An import of a stylesheet, an image, a font or a data file names a real file this walk does not
# census. Counted apart so "did not resolve" can be read: external packages and assets are
# correct to drop; LOCAL misses are the ones that mean the resolver is blind somewhere.
ASSET_SPEC = re.compile(r'\.(?:css|scss|sass|less|styl|pcss|svg|png|jpe?g|gif|webp|avif|ico|bmp|'
                        r'woff2?|ttf|otf|eot|json|jsonc|ya?ml|toml|md|mdx|txt|html?|wasm|mp4|webm|'
                        r'mp3|wav|ogg|glsl|wgsl|graphql|gql|csv|pdf)(?:\?.*)?$|\?(?:raw|url|inline|'
                        r'worker|react|component)\b', re.I)
SIGILS = ("@/", "~/", "#/")
JS_TO_TS = {".js": (".ts", ".tsx"), ".jsx": (".tsx",), ".mjs": (".mts",), ".cjs": (".cts",)}


class Resolver:
    """Specifier -> repo-relative source path, using every table the repo declares. Never guesses:
    each rule below is either a config the compiler/package manager reads, or the pre-existing
    sigil/rooted fallback."""

    def __init__(self, root, index, dart_pkg=None):
        self.root, self.index, self.dart_pkg = root, index, dart_pkg
        self.scopes = {}                     # dir -> (rules, baseUrl) ; "" is the root
        self.pkg_dirs = {""}
        for name in ROOT_CONFIG_NAMES:
            cand = os.path.join(root, name)
            if os.path.isfile(cand):
                self.scopes[""] = config_rules(cand, root)
                break
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(d for d in dirnames if d not in PRUNE and not d.startswith("."))
            rel = _rel_or_none(dirpath, root)
            if rel is None:
                continue
            if rel and "package.json" in filenames:
                self.pkg_dirs.add(rel)
            if rel:
                for name in CONFIG_NAMES:
                    if name in filenames:
                        self.scopes[rel] = config_rules(os.path.join(dirpath, name), root)
                        break
            if "package.json" in filenames:
                mnm, _ = package_json_aliases(dirpath)
                if mnm:
                    r, b = self.scopes.get(rel, ([], None))
                    prefix = (rel + "/") if rel else ""
                    self.scopes[rel] = (r + [(p, s, [prefix + t for t in ts]) for p, s, ts in mnm], b)
        for k, (r, b) in list(self.scopes.items()):
            self.scopes[k] = (sorted(r, key=lambda x: len(x[0]), reverse=True), b)
        self.pkgs = workspace_packages(root)
        self._scope_cache = {}

    @property
    def alias_rule_count(self):
        return sum(len(r) for r, _ in self.scopes.values())

    def _ancestors(self, d):
        while True:
            yield d
            if not d:
                return
            d = os.path.dirname(d)

    def _scope(self, d):
        """(rules of the nearest scope that has any, baseUrl of the nearest that sets one)."""
        if d not in self._scope_cache:
            rules = base = None
            for a in self._ancestors(d):
                if a in self.scopes:
                    r, b = self.scopes[a]
                    if rules is None and r:
                        rules = r
                    if base is None and b is not None:
                        base = b
                if rules is not None and base is not None:
                    break
            self._scope_cache[d] = (rules or [], base)
        return self._scope_cache[d]

    def _pkg_root(self, d):
        for a in self._ancestors(d):
            if a in self.pkg_dirs:
                return a
        return ""

    def _ts_bases(self, spec, here):
        """(bases, local?) for a TS/JS non-relative specifier."""
        rules, base = self._scope(here)
        bases = list(apply_aliases(spec, rules))
        local = bool(bases)
        if base is not None:
            # baseUrl alone makes `src/modules/x` (and `modules/x`) resolvable from that dir.
            bases.append((base + "/" + spec) if base else spec)
        hit, ws = workspace_bases(spec, self.pkgs)
        if hit:
            bases += ws
            local = True
        if spec[:2] in SIGILS:
            local = True
            tail = spec[2:]
            pr = self._pkg_root(here)
            # The nearest package first: `@/x` in apps/web means apps/web/src/x, not <root>/src/x.
            if pr:
                bases += [pr + "/" + p + tail for p in ("", "src/", "app/", "lib/")]
            bases.append(tail)               # then the repo root (src/ app/ lib/ tried below)
        elif "/" in spec and not spec.startswith("@"):
            bases.append(spec)               # rooted, e.g. `src/billing/charge`
        return bases, local

    def resolve(self, spec, rel):
        """A repo-relative source path, or None."""
        return self._resolve(spec, rel)[0]

    def _resolve(self, spec, rel):
        """(path or None, local?) — local means the specifier named something in this repo."""
        index = self.index
        here = os.path.dirname(rel)
        if rel.endswith(DART_EXT):
            if spec.startswith("dart:"):
                return None, False
            if spec.startswith("package:"):
                pkg, _, tail = spec[len("package:"):].partition("/")
                if not tail or self.dart_pkg is None or pkg != self.dart_pkg:
                    return None, False
                candidates, local = ["lib/" + tail], True
            else:
                candidates = [os.path.normpath(os.path.join(here, spec)).replace(os.sep, "/")]
                local = True
        elif rel.endswith(PY_EXT):
            if spec.startswith("."):
                up = len(spec) - len(spec.lstrip("."))
                base = here
                for _ in range(up - 1):
                    base = os.path.dirname(base)
                cand = os.path.normpath(os.path.join(base, spec.lstrip(".").replace(".", "/")))
                local = True
            else:
                cand = spec.replace(".", "/")
                local = False
            candidates = [cand + ".py", cand + "/__init__.py"]
        else:
            if spec.startswith("."):
                bases, local = [os.path.normpath(os.path.join(here, spec))], True
            else:
                bases, local = self._ts_bases(spec, here)
            if not bases:
                return None, local
            candidates = []
            for cand in bases:
                cand = cand.replace(os.sep, "/")
                stem, ext = os.path.splitext(cand)
                if ext in SOURCE_EXT:
                    candidates.append(cand)
                # ESM-style TypeScript writes the OUTPUT extension (`./schema.js`) and the
                # compiler maps it back to the source (`./schema.ts`) — its own rule, not a guess.
                for e in JS_TO_TS.get(ext, ()):
                    candidates.append(stem + e)
                for e in TS_EXT + SFC_EXT:
                    candidates.append(cand + e)
                    candidates.append(cand + "/index" + e)
        for c in candidates:
            c = c.lstrip("./")
            if c in index:
                return c, True
            for prefix in ("src/", "app/", "lib/"):
                if (prefix + c) in index:
                    return prefix + c, True
        return None, local

    def classify(self, spec, rel):
        """'external' | 'asset' | 'local' for a specifier that did not resolve."""
        if ASSET_SPEC.search(spec):
            return "asset"
        return "local" if self._resolve(spec, rel)[1] else "external"


def resolve(spec, rel, index, aliases=(), dart_pkg=None):
    """Back-compat single-table entry point (one alias table, no scopes, no workspaces)."""
    r = Resolver.__new__(Resolver)
    r.root, r.index, r.dart_pkg = "", index, dart_pkg
    r.scopes, r.pkg_dirs, r.pkgs, r._scope_cache = {"": (list(aliases), None)}, {""}, {}, {}
    return r.resolve(spec, rel)


def ts_wrapper(root, scope_dir, res):
    """A self-contained tsconfig for one project dir, for a resolver run OUTSIDE the repo.

    dependency-cruiser on a read-only checkout has to run with its config in a scratch folder.
    Measured 2026-10-15 on a real NestJS + React monorepo: a scratch tsconfig that only
    `extends` the app's own config resolved 0 of 10,314 aliased imports; one with an ABSOLUTE
    `baseUrl` and the `paths` table written out resolved them (39,313 edges). This prints the
    second shape: absolute baseUrl, the effective `paths` (after `extends`) made absolute, one
    entry per workspace package export mapped to its source file (there is no node_modules
    symlink to follow on a checkout nobody installed), and `include` = the dir's src/ (or the
    dir). No `extends` at all, so nothing is resolved relative to the scratch folder.
    """
    d_abs = os.path.normpath(os.path.join(root, scope_dir))
    cfg = None
    for name in CONFIG_NAMES + (("tsconfig.base.json",) if scope_dir in ("", ".") else ()):
        c = os.path.join(d_abs, name)
        if os.path.isfile(c):
            cfg = c
            break
    eff = _effective(cfg, root) if cfg else {}
    co = {k[4:]: v for k, v in eff.items() if k.startswith("opt:")}
    co["baseUrl"] = eff.get("baseUrl") or d_abs
    paths = {}
    if isinstance(eff.get("paths"), dict):
        pbase = eff.get("baseUrl") or eff["paths_dir"]
        for key, targets in eff["paths"].items():
            if isinstance(targets, list):
                paths[key] = [os.path.normpath(os.path.join(pbase, t)) for t in targets
                              if isinstance(t, str)]
    probe = os.path.join(scope_dir, "__probe__.ts").lstrip("./")
    for name, pkg in sorted(res.pkgs.items()):
        if pkg["dir"] == scope_dir or name in paths:
            continue
        subs = ["."]
        exp = pkg["exports"]
        if isinstance(exp, dict) and any(k.startswith(".") for k in exp):
            subs = [k for k in exp if "*" not in k]
        for sub in subs:
            spec = name if sub == "." else name + sub[1:]
            tgt = res.resolve(spec, probe)
            if tgt:
                paths[spec] = [os.path.join(root, tgt)]
        if not isinstance(exp, dict) or not any(k.startswith(".") for k in exp):
            paths[name + "/*"] = [os.path.join(root, pkg["dir"], "*")]
    if paths:
        co["paths"] = paths
    inc = os.path.join(d_abs, "src") if os.path.isdir(os.path.join(d_abs, "src")) else d_abs
    return {"compilerOptions": co, "include": [inc]}


def write_routed_disclosure(routed):
    for name, dirs in routed or ():
        sys.stderr.write("NOT AN EDGE SOURCE: %s routes from %s by FILE PATH, not by import. Files "
                         "there having no importers is correct and is NOT a clearance to change "
                         "them; a component used only inside a <template> under auto-import "
                         "produces no specifier either.\n" % (name, "/, ".join(dirs) + "/"))


def write_alias_disclosure(blind):
    if blind:
        sys.stderr.write("NOT READ: %s declare aliases in JavaScript. Reading them means executing "
                         "JS; a regex scrape would be a guess. Edges through those aliases are "
                         "MISSING, not absent — unless a tsconfig `paths` entry declares the same "
                         "alias, which IS read.\n" % ", ".join(blind))


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("repo")
    ap.add_argument("--limit", type=int, default=0, help="0 = rank everything")
    ap.add_argument("--format", choices=("table", "list", "json"), default="table")
    ap.add_argument("--include-tests", action="store_true")
    ap.add_argument("--hub-share", type=float, default=0.75,
                    help="fraction of --limit given to hubs (default 0.75)")
    ap.add_argument("--emit-edges", metavar="PATH",
                    help="write every RESOLVED import edge as TSV (kind, importer, imported, label: '' "
                         "value · 'type' every statement type-only · 'dynamic' import() only) "
                         "and exit. A specifier that did not resolve is not an edge and is not "
                         "written; the count of those is reported on stderr rather than dropped "
                         "silently. --limit does not apply: a ranking is a selection, a graph is "
                         "not, and emitting only the top N would produce a map whose missing "
                         "edges look like absent dependencies.")
    ap.add_argument("--ts-wrapper", metavar="DIR",
                    help="print a self-contained tsconfig (absolute baseUrl + paths, workspace "
                         "packages mapped to source, no extends) for DIR (repo-relative) and "
                         "exit — for running dependency-cruiser from a scratch folder against a "
                         "read-only checkout")
    args = ap.parse_args()

    root = os.path.abspath(args.repo)
    if not os.path.isdir(root):
        sys.stderr.write("no such directory: %s\n" % args.repo)
        return 2
    if args.ts_wrapper is not None:
        d = os.path.normpath(args.ts_wrapper).replace(os.sep, "/").strip("/")
        d = "" if d == "." else d
        if not os.path.isdir(os.path.join(root, d)):
            sys.stderr.write("no such directory in the repo: %s\n" % args.ts_wrapper)
            return 2
        files = walk(root, True)
        print(json.dumps(ts_wrapper(root, d, Resolver(root, set(files))), indent=2))
        return 0

    files = walk(root, args.include_tests)
    index = set(files)
    res = Resolver(root, index, dart_package_name(root))
    n_alias = res.alias_rule_count
    blind = alias_blind_spots(root, res.pkg_dirs)
    routed = routed_blind_spots(root, res.pkg_dirs)
    parseable = [f for f in files if f.endswith(SOURCE_EXT)]

    importers = {f: set() for f in files}          # file -> set of files importing it
    out_deg = {f: set() for f in files}
    edge_kinds = {}                                 # (importer, imported) -> statement kinds
    unresolved = 0
    kinds = {"external": 0, "asset": 0, "local": 0}
    local_examples = {}
    for f in parseable:
        for spec, sk in specifier_kinds(f, read(os.path.join(root, f))):
            tgt = res.resolve(spec, f)
            if tgt is None or tgt == f:
                unresolved += 1
                k = "local" if tgt == f else res.classify(spec, f)
                kinds[k] += 1
                if k == "local":
                    local_examples.setdefault(spec, f)
                continue
            importers[tgt].add(f)
            out_deg[f].add(tgt)
            edge_kinds.setdefault((f, tgt), set()).add(sk)
    breakdown = ("%d external package(s) · %d asset(s) · %d local miss(es)"
                 % (kinds["external"], kinds["asset"], kinds["local"]))
    scope_note = ("%d alias rule(s) read from %d tsconfig/package.json scope(s); %d workspace "
                  "package(s)" % (n_alias, sum(1 for r, _ in res.scopes.values() if r),
                                  len(res.pkgs)))

    if args.emit_edges:
        with open(args.emit_edges, "w", encoding="utf-8") as fh:
            for f in sorted(out_deg):
                for tgt in sorted(out_deg[f]):
                    k = edge_kinds.get((f, tgt), {"value"})
                    # label: '' a value edge (runs at init) · 'type' erased by the compiler ·
                    # 'dynamic' only import() — the last two cannot close an init-order cycle.
                    lab = "" if "value" in k else ("dynamic" if "dynamic" in k else "type")
                    fh.write("code\t%s\t%s\t%s\n" % (f, tgt, lab))
        n = sum(len(v) for v in out_deg.values())
        n_val = sum(1 for k in edge_kinds.values() if "value" in k)
        sys.stderr.write("%d resolved edge(s) written (%d value, %d type-only or import()-only); "
                         "%d specifier(s) did not resolve (dropped, not guessed: %s); %s\n"
                         % (n, n_val, n - n_val, unresolved, breakdown, scope_note))
        if kinds["local"]:
            ex = sorted(local_examples.items())[:5]
            sys.stderr.write("LOCAL MISSES (a relative path, an alias or a workspace package that "
                             "named no source file), e.g. %s\n"
                             % "; ".join("%s in %s" % (s_, f_) for s_, f_ in ex))
        write_alias_disclosure(blind)
        write_routed_disclosure(routed)
        return 0

    rows = []
    for f in files:
        ins = importers[f]
        dirs = {os.path.dirname(i) for i in ins}
        kind = "hub" if ins else ("root" if out_deg[f] else "isolated")
        rows.append({
            "path": f, "kind": kind,
            "importers": len(ins), "importer_dirs": len(dirs), "imports": len(out_deg[f]),
        })

    hubs = sorted([r for r in rows if r["kind"] == "hub"],
                  key=lambda r: (-r["importer_dirs"], -r["importers"], r["path"]))
    roots = sorted([r for r in rows if r["kind"] == "root"],
                   key=lambda r: (-r["imports"], r["path"]))
    rest = sorted([r for r in rows if r["kind"] == "isolated"], key=lambda r: r["path"])

    if args.limit:
        # Clamp first. A share outside [0,1] made n_root negative, and `roots[:negative]` slices
        # from the END of the list rather than returning nothing — so `--limit 8 --hub-share 1.5`
        # returned 20 rows, silently over-spending a budget the caller set precisely.
        if not 0.0 <= args.hub_share <= 1.0:
            sys.stderr.write("--hub-share must be between 0 and 1 (got %r)\n" % args.hub_share)
            return 2
        n_hub = min(len(hubs), int(round(args.limit * args.hub_share)))
        n_root = min(len(roots), args.limit - n_hub)
        n_hub = min(len(hubs), args.limit - n_root)
        picked = hubs[:n_hub] + roots[:n_root]
        picked += rest[:max(0, args.limit - len(picked))]
    else:
        picked = hubs + roots + rest

    write_alias_disclosure(blind)
    write_routed_disclosure(routed)

    if args.format == "json":
        print(json.dumps({
            "present": len(files), "selected": len(picked),
            "hubs": len(hubs), "roots": len(roots), "isolated": len(rest),
            "unresolved_specifiers": unresolved, "unresolved_kinds": kinds,
            "alias_rules": n_alias, "alias_configs_not_read": blind,
            "workspace_packages": sorted(res.pkgs),
            "rows": picked}, indent=2))
        return 0

    if args.format == "list":
        for r in picked:
            print(r["path"])
        return 0

    print("# rank-source-files — %d/%d source files selected" % (len(picked), len(files)))
    print("# hubs %d · roots %d · isolated %d · %d specifiers did not resolve (dropped, not "
          "guessed: %s) · %s"
          % (len(hubs), len(roots), len(rest), unresolved, breakdown, scope_note))
    print("# walk_scope: centrality-ranked (importing dirs, then importer count); "
          "hub share %.2f" % args.hub_share)
    print("%-4s %-9s %7s %7s %7s  %s" % ("#", "kind", "impBy", "impDirs", "imports", "path"))
    for i, r in enumerate(picked, 1):
        print("%-4d %-9s %7d %7d %7d  %s"
              % (i, r["kind"], r["importers"], r["importer_dirs"], r["imports"], r["path"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

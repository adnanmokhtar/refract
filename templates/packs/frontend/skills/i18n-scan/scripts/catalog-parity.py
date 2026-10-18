#!/usr/bin/env python3
"""catalog-parity.py — i18n-scan §2 and §9: key, placeholder and plural-form parity across every
locale catalog in a repo, plus the locale-count gate. Stdlib only. Reads files; never writes.

Usage:  catalog-parity.py [<repo>] [--locales=ar,en] [--base=en] [--used=<root>,<root>…]
                          [--max=40] [--json] [--v1=<laravel-root>]
        catalog-parity.py --self-test
Exit:   0  no finding (or the lane is gated off)   1  at least one finding   2  usage or read error

WHAT COUNTS AS A CATALOG. A file whose path carries a locale token, in one of these shapes:
  JSON / YAML / TS / JS   locales/ar.json · i18n/ar/errors.json · i18n.ar.json · messages_ar.yml · ar.ts
  Flutter ARB             app_ar.arb                     (`@key` metadata is skipped)
  Android                 res/values-ar/strings.xml      (`values/` is the default locale; translatable="false" skipped)
  iOS                     ar.lproj/Localizable.strings · Localizable.xcstrings (all locales in one file)
  gettext                 locale/ar/LC_MESSAGES/django.po (fuzzy or empty msgstr = untranslated)
  Angular XLIFF           messages.ar.xlf beside the source messages.xlf
JSON/YAML/TS/JS also need a catalog-ish directory or name (locales, i18n, l10n, lang, translations,
messages, intl) or a file named exactly for its locale. A token is an ISO 639-1 code (+ region or
script), or any code passed in --locales. Tests, fixtures, build output and vendored trees are skipped.

A SET is the files that differ only by the locale token. Parity is computed per set, and the
locales a set must have are the locales its catalog family (web, android, ios, arb, po, xlf) declares
within the same package — the nearest directory above it with a package.json, else the repo — so two
apps of a monorepo that ship different locales are never told they lack each other's.

FINDINGS (exit 1):
  missing-file     a set has no file for a locale its family declares in the same package
  missing-key      a key one locale of the set has and another lacks (i18next plural suffixes and
                   Android/ICU plural forms are folded into their base key first)
  placeholder      the interpolation tokens of one key differ between locales ({{n}} vs {n}, %1$s vs %s)
  plural-forms     a plural key lacks a CLDR category the locale needs (Intl.PluralRules via node;
                   a small built-in table when node is absent — other locales print `plural-check: blocked`)
  untranslated     an empty value, a fuzzy/empty msgstr, an XLIFF target that is missing or not final,
                   an xcstrings localization that is missing or not `translated`
  used-undefined   (--used) a literal key in code that no catalog defines under any namespace
CROSS-TREE (--v1=<root>: a Laravel V1 being ported; reads <root>/lang/ and <root>/resources/lang/ —
  <locale>/**/*.php `return [...]` arrays as `<file>.<dotted key>`, and <locale>.json as flat keys; never
  writes there). A V1 key is matched to a V2 key of the same name, or of the same name under the V2 file's
  stem (lang/ar/orders.php `orders.paid` ↔ locales/ar/orders.json `paid`), in the same locale.
  v1-plural-forms  (finding) a V1 pipe plural (`a|b`, `{0} a|[1,19] b|[20,*] c`) whose V2 key lacks a CLDR
                   category the locale needs — Arabic needs zero one two few many other
  v1-plural-lost   (finding) a V1 plural (ranges, `:count`, or 3+ forms) whose V2 key has one form only
  v1-placeholder   (finding) the V1 `:name` set differs from the V2 {{name}} / {name} set (case-folded)
  v1-plural-range  (candidate) V1 selects by number range, which CLDR categories cannot express
  v1-pipe-text     (candidate) a 2-part `a|b` with no :count — a plural or a literal pipe
  v1-unmapped      (candidate) V1 keys with no V2 key of that name, per locale: renamed or dropped
CANDIDATES (printed, never exit 1 — each needs a read):
  same-as-base     a value identical to the base locale's (brand names and units are legitimate)
  dynamic-prefix   (--used) t(`status.${x}`) / t('status.' + x), and `${KEY}.jt.${x}` where KEY is a string
                   constant ('ns:carrierReason'): the prefix and the keys under it — cross them with the
                   variable's bound (i18n-scan §2, the prefix × union sweep). A template whose head is
                   itself a variable (`${group}.${key}.label`) prints as `<fully dynamic>`.
  unused-key       (--used) a base key with no literal reference and no dynamic prefix above it
  placeholder-token  a value that is exactly one placeholder token in every locale ({{variable}} vs
                   {{متغير}}), or a key read with skipInterpolation — a display token, not an argument
  untranslated-slot  an empty value whose siblings form one sentence (heroTitleA / heroTitleMid /
                   heroTitleB): a word-order slot one locale leaves empty on purpose
"""
import json, os, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

ISO639_1 = set(
    "aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu cv cy da de dv dz "
    "ee el en eo es et eu fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io "
    "is it iu ja jv ka kg ki kj kk kl km kn ko kr ks ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr "
    "ms mt my na nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd se sg si "
    "sk sl sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve vi vo wa wo xh "
    "yi yo za zh zu".split())
# Two-letter words that are far more often a directory or a file than a language in a code tree.
NOT_A_LOCALE_DIR = {"js", "ts", "db", "ui", "io", "os", "ci", "cd", "id", "is", "it", "to", "no", "or", "am", "an",
                    "as", "be", "do", "go", "in", "me", "my", "on", "so", "up", "us", "we", "ok", "pa", "mk", "co"}
RTL = {"ar", "he", "fa", "ur", "ps", "sd", "ug", "yi", "dv", "ku", "ckb", "iw"}
SKIP_DIRS = {"node_modules", ".git", "dist", "build", "out", ".next", ".nuxt", ".output", ".svelte-kit", ".angular",
             "coverage", "vendor", "Pods", "DerivedData", ".gradle", ".dart_tool", "target", ".venv", "venv",
             "__pycache__", "storybook-static", ".turbo", ".cache", "test", "tests", "__tests__", "__mocks__",
             "mocks", "fixtures", "__fixtures__", "e2e", "testdata", "playwright-report", "scripts", "tools",
             "stories"}
CATALOG_HINT = re.compile(r"(?:^|[/._-])(?:locales?|i18n|l10n|lang|langs|languages|translations?|messages|intl|"
                          r"strings|lproj)(?:$|[/._-])", re.I)
TOKEN = r"([a-z]{2,3})(?:[-_](?:r)?([A-Z]{2}|[A-Z][a-z]{3}|\d{3}))?"
PLURAL_SUFFIX = re.compile(r"^(.*?)_(?:ordinal_)?(zero|one|two|few|many|other)$")
PLURAL_TABLE = {"en": "one other", "de": "one other", "nl": "one other", "sv": "one other", "da": "one other",
                "ar": "zero one two few many other", "ja": "other", "zh": "other", "ko": "other", "tr": "one other"}
CODE_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte", ".html", ".astro")
FAMILY = {"json": "web", "yaml": "web", "ts": "web", "arb": "arb", "android": "android", "strings": "ios",
          "xcstrings": "ios", "po": "po", "xlf": "xlf"}


def die(msg):
    print(f"catalog-parity: {msg}", file=sys.stderr); sys.exit(2)


# ── locale token in a path ──────────────────────────────────────────────────────────────────────
def lang_ok(code, extra):
    return code in extra or code in ISO639_1


def norm(lang, region):
    return lang + ("-" + region if region else "")


def locate(rel, extra):
    """Return (kind, locale, set_id) or None. set_id has the token replaced by {L}."""
    parts = rel.split("/")
    name = parts[-1]
    stem, ext = os.path.splitext(name)
    ext = ext.lower()
    if name == "strings.xml" and len(parts) >= 2 and parts[-2].startswith("values"):
        q = parts[-2][len("values"):]
        if q == "":
            return "android", "_default", "/".join(parts[:-2] + ["values{L}", name])
        m = re.fullmatch(r"-" + TOKEN, q) or re.fullmatch(r"-b\+([a-z]{2,3})(?:\+([A-Za-z0-9]+))?", q)
        if m and lang_ok(m.group(1), extra):
            return "android", norm(m.group(1), m.group(2)), "/".join(parts[:-2] + ["values{L}", name])
        return None
    if ext == ".xcstrings":
        return "xcstrings", "*", rel
    if ext in (".xlf", ".xliff"):
        m = re.fullmatch(r"(.+)\." + TOKEN, stem)
        if m and lang_ok(m.group(2), extra):
            return "xlf", norm(m.group(2), m.group(3)), "/".join(parts[:-1] + [m.group(1) + ".{L}" + ext])
        return "xlf", "_src", "/".join(parts[:-1] + [stem + ".{L}" + ext])
    kind = {".json": "json", ".yml": "yaml", ".yaml": "yaml", ".arb": "arb", ".strings": "strings", ".po": "po",
            ".ts": "ts", ".js": "ts", ".mjs": "ts"}.get(ext)
    if not kind or name.endswith((".d.ts", ".test.ts", ".spec.ts", ".config.ts", ".config.js")):
        return None
    if name in ("package.json", "tsconfig.json", "composer.json") or stem.startswith("tsconfig"):
        return None
    # 1. the stem is the token: en.json, ar.ts, ar.po
    m = re.fullmatch(TOKEN, stem)
    if m and lang_ok(m.group(1), extra) and (kind != "ts" or CATALOG_HINT.search("/".join(parts[:-1]))):
        if not (kind in ("json", "yaml", "ts") and m.group(1) in NOT_A_LOCALE_DIR and not CATALOG_HINT.search(rel)):
            return kind, norm(m.group(1), m.group(2)), "/".join(parts[:-1] + ["{L}" + ext])
    # 2. a directory: i18n/ar/errors.json, ar.lproj/Localizable.strings, locale/ar/LC_MESSAGES/x.po —
    #    before the suffix, so i18n/en/team-hr.json is `en`, never `hr`.
    if kind != "ts":
        for i in range(len(parts) - 2, -1, -1):
            seg = parts[i]
            lproj = seg.endswith(".lproj")
            m = re.fullmatch(TOKEN, seg[:-6] if lproj else seg)
            if not m or not lang_ok(m.group(1), extra):
                continue
            if not lproj and m.group(1) in NOT_A_LOCALE_DIR and m.group(1) not in extra:
                continue
            if lproj or kind == "po" or CATALOG_HINT.search("/".join(parts[:i]) + "/"):
                new = list(parts); new[i] = "{L}" + (".lproj" if lproj else "")
                return kind, norm(m.group(1), m.group(2)), "/".join(new)
    # 3. a suffix: i18n.ar.json, app_ar.arb, messages-ar.yml
    m = re.fullmatch(r"(.+?)([._-])" + TOKEN, stem)
    if m and lang_ok(m.group(3), extra) and (kind == "arb" or CATALOG_HINT.search(rel)):
        if m.group(3) not in NOT_A_LOCALE_DIR or kind == "arb":
            return kind, norm(m.group(3), m.group(4)), "/".join(parts[:-1] + [m.group(1) + m.group(2) + "{L}" + ext])
    return None


# ── parsers: each returns {key: value} (value is a string, or None for "untranslated") ──────────
def flatten(obj, prefix, out):
    if isinstance(obj, dict):
        for k, v in obj.items():
            flatten(v, f"{prefix}.{k}" if prefix else str(k), out)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            flatten(v, f"{prefix}[{i}]", out)
    else:
        out[prefix] = "" if obj is None else str(obj)


def unwrap(obj, locale):
    if isinstance(obj, dict) and len(obj) == 1:
        (k, v), = obj.items()
        if isinstance(v, dict) and str(k).replace("_", "-").lower() == locale.lower():
            return v
    return obj


def read_text(path):
    raw = open(path, "rb").read()
    for enc in ("utf-8-sig", "utf-16"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("latin-1")


def mini_yaml(text):
    root, stack = {}, [(-1, None)]
    stack[0] = (-1, root)
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith(("#", "---")):
            continue
        ind = len(line) - len(line.lstrip(" "))
        m = re.match(r"\s*(['\"]?)([^'\":#][^:]*?|[^'\"]*)\1\s*:(?:\s+(.*))?$", line)
        if not m:
            continue
        while stack and stack[-1][0] >= ind:
            stack.pop()
        parent = stack[-1][1]
        key, val = m.group(2).strip(), (m.group(3) or "").strip()
        if val in ("", "|", ">", "|-", ">-"):
            node = {} if val == "" else ""
            parent[key] = node
            if isinstance(node, dict):
                stack.append((ind, node))
        else:
            parent[key] = val.strip("'\"")
    return root


def js_object_keys(text):
    """Leaf keys of the first object literal in a TS/JS catalog (export default {…} / const x = {…})."""
    text = re.sub(r"/\*[\s\S]*?\*/", " ", text)
    text = re.sub(r"(?m)(^|[^:])//[^\n]*", r"\1", text)
    start = text.find("{", max(text.find("export default"), text.find("= {") if "= {" in text else 0, 0))
    if start < 0:
        return {}
    out, path, i, n, expect_key, key = {}, [], start + 1, len(text), True, None
    while i < n:
        c = text[i]
        if c in " \t\r\n,":
            if c == ",":
                expect_key = True
            i += 1; continue
        if c == "}":
            if not path:
                break
            path.pop(); i += 1; expect_key = False; continue
        if expect_key:
            m = re.compile(r"(['\"`])((?:\\.|(?!\1).)*)\1\s*:|([A-Za-z_$][\w$]*)\s*:|\.\.\.[\w$.]+|\[").match(text, i)
            if not m:
                i += 1; continue
            if m.group(0).startswith("...") or m.group(0) == "[":
                i = m.end(); expect_key = False; continue
            key = m.group(2) if m.group(1) else m.group(3)
            i = m.end(); expect_key = False
            j = i
            while j < n and text[j] in " \t\r\n":
                j += 1
            if j < n and text[j] == "{":
                path.append(key); i = j + 1; expect_key = True; continue
            # a leaf value: a string, or anything up to the next top-level comma or closing brace
            m2 = re.compile(r"(['\"`])((?:\\.|(?!\1).)*)\1").match(text, j)
            if m2:
                out[".".join(path + [key])] = m2.group(2); i = m2.end()
            else:
                depth, k = 0, j
                while k < n and not (depth == 0 and text[k] in ",}"):
                    depth += text[k] in "([{"; depth -= text[k] in ")]}"; k += 1
                out[".".join(path + [key])] = text[j:k].strip(); i = k
            continue
        i += 1
    return out


def parse(kind, path, locale):
    """Return ({key: value|None}, {base_key: set(plural forms)}, note)."""
    vals, forms, note = {}, {}, ""
    if kind in ("json", "arb"):
        data = unwrap(json.loads(read_text(path)), locale)
        if kind == "arb":
            data = {k: v for k, v in data.items() if not k.startswith("@")}
        flatten(data, "", vals)
    elif kind == "yaml":
        text = read_text(path)
        try:
            import yaml  # noqa: PLC0415 — optional; the built-in reader covers plain nested maps
            data = yaml.safe_load(text) or {}
        except ImportError:
            data, note = mini_yaml(text), "yaml: built-in reader (plain nested maps only)"
        flatten(unwrap(data, locale), "", vals)
    elif kind == "ts":
        vals = js_object_keys(read_text(path))
    elif kind == "strings":
        for m in re.finditer(r'(?m)^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', read_text(path)):
            vals[m.group(1)] = m.group(2)
    elif kind == "po":
        text, fuzzy = read_text(path), False
        for block in re.split(r"\n\s*\n", text):
            if "msgid" not in block:
                continue
            fuzzy = bool(re.search(r"(?m)^#,.*\bfuzzy\b", block))
            def field(name):
                m = re.search(r'(?m)^' + re.escape(name) + r'\s+((?:"(?:[^"\\]|\\.)*"\s*)+)', block)
                return None if not m else "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)))
            mid, ctx = field("msgid"), field("msgctxt")
            if not mid:
                continue
            key = (ctx + "\x04" if ctx else "") + mid
            strs = [field(f"msgstr[{k}]") for k in range(6)]
            strs = [s for s in strs if s is not None] or [field("msgstr")]
            vals[key] = None if fuzzy or not all(strs) else strs[0]
    elif kind == "android":
        root = ET.parse(path).getroot()
        for el in root:
            name, tag = el.get("name"), el.tag
            attrs = {k.split("}")[-1]: v for k, v in el.attrib.items()}
            if not name or attrs.get("translatable") == "false" or "MissingTranslation" in attrs.get("ignore", ""):
                continue
            if tag == "string":
                vals[name] = "".join(el.itertext())
            elif tag == "plurals":
                q = {it.get("quantity") for it in el if it.get("quantity")}
                forms[name] = q
                vals[name] = " | ".join("".join(it.itertext()) for it in el)
            elif tag == "string-array":
                for i, it in enumerate(el):
                    vals[f"{name}[{i}]"] = "".join(it.itertext())
    elif kind == "xlf":
        root = ET.parse(path).getroot()
        for el in root.iter():
            tag = el.tag.split("}")[-1]
            if tag not in ("trans-unit", "unit") or not el.get("id"):
                continue
            tgt = next((c for c in el.iter() if c.tag.split("}")[-1] == "target"), None)
            seg = next((c for c in el.iter() if c.tag.split("}")[-1] == "segment"), None)
            state = (tgt.get("state") if tgt is not None else None) or (seg.get("state") if seg is not None else None)
            if locale == "_src":
                vals[el.get("id")] = "src"
            elif tgt is None or not "".join(tgt.itertext()).strip() or state in ("new", "needs-translation", "initial"):
                vals[el.get("id")] = None
            else:
                vals[el.get("id")] = "".join(tgt.itertext())
    return vals, forms, note


def parse_xcstrings(path):
    """{locale: ({key: value|None}, {key: forms})}, source language."""
    data = json.loads(read_text(path))
    src, per = data.get("sourceLanguage", "en"), {}
    langs = {src}
    for entry in data.get("strings", {}).values():
        langs |= set((entry or {}).get("localizations", {}))
    for lang in langs:
        per[lang] = ({}, {})
    for key, entry in data.get("strings", {}).items():
        entry = entry or {}
        if entry.get("shouldTranslate") is False or entry.get("extractionState") == "stale":
            continue
        locs = entry.get("localizations", {})
        for lang in langs:
            loc = locs.get(lang)
            if loc is None:
                per[lang][0][key] = key if lang == src else None
                continue
            unit = loc.get("stringUnit")
            plural = (loc.get("variations") or {}).get("plural")
            if plural:
                per[lang][1][key] = set(plural)
                states = {(v.get("stringUnit") or {}).get("state") for v in plural.values()}
                per[lang][0][key] = None if states - {"translated"} else " | ".join(
                    (v.get("stringUnit") or {}).get("value", "") for v in plural.values())
            elif unit:
                per[lang][0][key] = unit.get("value") if unit.get("state", "translated") == "translated" else None
            else:
                per[lang][0][key] = None
    return per, src


# ── placeholders ────────────────────────────────────────────────────────────────────────────────
def icu(s):
    """Argument names and plural option keys of an ICU message. Literal text in branches is not an arg."""
    args, plural, n = set(), {}, len(s)

    def skip(i):
        depth = 1
        while i < n and depth:
            depth += {"{": 1, "}": -1}.get(s[i], 0); i += 1
        return i

    def text(i, depth):
        while i < n:
            c = s[i]
            if c == "'" and i + 1 < n and s[i + 1] in "{}":
                j = s.find("'", i + 1); i = n if j < 0 else j + 1; continue
            if c == "{":
                i = arg(i + 1); continue
            if c == "}" and depth:
                return i + 1
            i += 1
        return i

    def arg(i):
        m = re.compile(r"\s*([A-Za-z_$][\w$.]*|\d+)\s*([,}])").match(s, i)
        if not m:
            return i
        args.add(m.group(1)); i = m.end()
        if m.group(2) == "}":
            return i
        m2 = re.compile(r"\s*(plural|selectordinal|select)\s*,").match(s, i)
        if not m2:
            return skip(i)
        i = m2.end()
        while i < n:
            m3 = re.compile(r"\s*(?:offset:\s*\d+\s*)?(=?[^\s{}]+)\s*\{").match(s, i)
            if m3:
                if m2.group(1) != "select" and not m3.group(1).startswith("="):
                    plural.setdefault(m.group(1), set()).add(m3.group(1))
                i = text(m3.end(), 1); continue
            m4 = re.compile(r"\s*\}").match(s, i)
            return m4.end() if m4 else skip(i)
        return i

    text(0, 0)
    return args, plural


PRINTF = re.compile(r"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j|L)?([@diuoxXfFeEgGcsS])")


def placeholders(value, kind):
    if not value:
        return (), {}
    toks = set(re.findall(r"\{\{\s*-?\s*([\w.$]+)", value))
    toks = {"{{%s}}" % t for t in toks}
    toks |= {"$t(%s)" % t for t in re.findall(r"\$t\(\s*([\w.:-]+)", value)}
    toks |= {"%%{%s}" % t for t in re.findall(r"%\{(\w+)\}", value)}
    toks |= {"@:%s" % t for t in re.findall(r"@:([\w.]+)", value)}
    rest = re.sub(r"\{\{[^}]*\}\}", " ", value)
    args, plural = icu(rest)
    toks |= {"{%s}" % a for a in args}
    if kind in ("android", "strings", "xcstrings", "po"):
        pos = sorted("%" + (m.group(1) + "$" if m.group(1) else "") + m.group(2).lower().replace("i", "d")
                     for m in PRINTF.finditer(value) if not value[max(0, m.start() - 1):m.start()] == "%")
        toks |= set(pos)
        toks |= {"%%(%s)" % t for t in re.findall(r"%\((\w+)\)[sd]", value)}
    return tuple(sorted(toks)), plural


# ── Intl.PluralRules ────────────────────────────────────────────────────────────────────────────
def required_forms(locales):
    real = sorted(l for l in locales if not l.startswith("_") and l != "*")
    out = {}
    try:
        res = subprocess.run(["node", "-e", "for (const l of process.argv.slice(1)) { try { console.log(l + ' ' + "
                              "new Intl.PluralRules(l).resolvedOptions().pluralCategories.join(',')) } catch (e) {} }",
                              *real], capture_output=True, text=True, timeout=20)
        for line in res.stdout.splitlines():
            l, cats = line.split(" ", 1)
            out[l] = set(cats.split(","))
        src = "node Intl.PluralRules"
    except (OSError, subprocess.SubprocessError):
        src = "built-in table (node not found)"
    for l in real:
        if l not in out and l.split("-")[0] in PLURAL_TABLE:
            out[l] = set(PLURAL_TABLE[l.split("-")[0]].split())
    return out, src


# ── cross-tree: a Laravel V1's lang/ catalog against this repo's catalogs ──────────────────────
LV_PH = re.compile(r"(?<![\w:/]):([A-Za-z_][A-Za-z0-9_]*)")      # :name, :Name, :NAME (Laravel replaces all three)
LV_RANGE = re.compile(r"^\s*(\{\s*-?\d+\s*\}|\[\s*(?:-?\d+|\*)\s*,\s*(?:-?\d+|\*)\s*\])")


def php_lang_array(text):
    """`return [ 'k' => 'v', 'n' => [ … ] ];` (or array( … )) -> flat {dotted key: str}; anything that is not a
    string literal (a concatenation of literals is joined) is skipped and counted. Comments are dropped."""
    toks, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in "'\"":
            j, buf = i + 1, []
            while j < n and text[j] != c:
                if text[j] == "\\" and j + 1 < n:
                    nx = text[j + 1]
                    buf.append(nx if (c == "'" and nx in "'\\") or (c == '"' and nx in '"\\$') else
                               ({"n": "\n", "t": "\t"}.get(nx, "\\" + nx) if c == '"' else "\\" + nx))
                    j += 2; continue
                buf.append(text[j]); j += 1
            toks.append(("S", "".join(buf))); i = j + 1; continue
        if text.startswith("//", i) or c == "#":
            j = text.find("\n", i); i = n if j < 0 else j; continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2); i = n if j < 0 else j + 2; continue
        if text.startswith("=>", i):
            toks.append(("=>", "")); i += 2; continue
        m = re.compile(r"(?i)array\s*\(").match(text, i)
        if m:
            toks.append(("[", "")); i = m.end(); continue
        if c in "[(":
            toks.append(("[" if c == "[" else "(", "")); i += 1; continue
        if c in "])":
            toks.append(("]" if c == "]" else ")", "")); i += 1; continue
        if c in ",.;":
            toks.append((c, "")); i += 1; continue
        m = re.compile(r"[\w$\\:>-]+").match(text, i)
        if m and m.end() > i:
            toks.append(("W", m.group(0))); i = m.end(); continue
        i += 1
    start = next((k for k, tk in enumerate(toks) if tk == ("W", "return")), None)
    out, skipped = {}, [0]
    if start is None or start + 1 >= len(toks) or toks[start + 1][0] != "[":
        return out, 1

    def value(k):
        if toks[k][0] == "S":
            s = toks[k][1]; k += 1
            while k + 1 < len(toks) and toks[k][0] == "." and toks[k + 1][0] == "S":
                s += toks[k + 1][1]; k += 2
            if k < len(toks) and toks[k][0] not in (",", "]", ")"):
                return None, skip(k)
            return s, k
        if toks[k][0] == "[":
            return array(k)
        return None, skip(k)

    def skip(k):
        d = 0
        while k < len(toks):
            if toks[k][0] in "[(": d += 1
            elif toks[k][0] in "])":
                if d == 0: return k
                d -= 1
            elif toks[k][0] == "," and d == 0: return k
            k += 1
        return k

    def array(k):
        node, k, idx = {}, k + 1, 0
        while k < len(toks) and toks[k][0] not in ("]", ")"):
            if toks[k][0] == ",":
                k += 1; continue
            key = None
            if toks[k][0] in ("S", "W") and k + 1 < len(toks) and toks[k + 1][0] == "=>":
                key = toks[k][1]; k += 2
            v, k = value(k)
            if v is None:
                skipped[0] += 1
            node[key if key is not None else str(idx)] = v
            if key is None: idx += 1
        return node, k + 1

    tree, _ = array(start + 1)
    def walk(o, pre):
        for kk, vv in o.items():
            key = f"{pre}.{kk}" if pre else str(kk)
            if isinstance(vv, dict): walk(vv, key)
            elif isinstance(vv, str): out[key] = vv
    walk(tree, "")
    return out, skipped[0]


def v1_catalogs(v1):
    """Laravel lang roots (lang/ since 9.x, resources/lang/ before): {locale: {key: value}}, files, notes."""
    per, files, notes = {}, [], []
    for base in ("lang", os.path.join("resources", "lang")):
        root = os.path.join(v1, base)
        if not os.path.isdir(root):
            continue
        for name in sorted(os.listdir(root)):
            p = os.path.join(root, name)
            m = re.fullmatch(r"([a-z]{2,3})(?:[-_]([A-Za-z]{2}|[A-Z][a-z]{3}))?(\.json)?", name)
            if name == "vendor":
                notes.append(f"{base}/vendor skipped (package overrides use `package::file.key`)"); continue
            if not m:
                continue
            loc = norm(m.group(1), m.group(2).upper() if m.group(2) and len(m.group(2)) == 2 else m.group(2))
            if m.group(3) and os.path.isfile(p):
                try:
                    data = json.loads(read_text(p))
                except ValueError as e:
                    notes.append(f"v1 read-error {base}/{name}: {e}"); continue
                per.setdefault(loc, {}).update({str(k): ("" if v is None else str(v)) for k, v in data.items()
                                                if isinstance(v, (str, int, float)) or v is None})
                files.append(os.path.join(base, name))
            elif os.path.isdir(p):
                for dp, dns, fns in os.walk(p):
                    dns.sort()
                    for fn in sorted(f for f in fns if f.endswith(".php")):
                        fp = os.path.join(dp, fn)
                        ns = os.path.relpath(fp, p)[:-4].replace(os.sep, "/")
                        vals, sk = php_lang_array(read_text(fp))
                        if sk:
                            notes.append(f"v1 {os.path.relpath(fp, v1)}: {sk} value(s) not a string literal, skipped")
                        per.setdefault(loc, {}).update({f"{ns}.{k}": v for k, v in vals.items()})
                        files.append(os.path.relpath(fp, v1))
    return per, files, notes


def lv_plural(v):
    """Laravel pluralisation of one value: (parts, has_range) for `a|b`, `{0} a|[1,19] b|[20,*] c`; None if no pipe."""
    parts = re.split(r"(?<!\\)\|", v or "")
    if len(parts) < 2 or not all(p.strip() for p in parts):
        return None
    return parts, any(LV_RANGE.match(p) for p in parts)


# ── the run ─────────────────────────────────────────────────────────────────────────────────────
def discover(repo, extra):
    found = []
    for dp, dns, fns in os.walk(repo):
        dns[:] = [d for d in dns if d not in SKIP_DIRS and not (d.startswith(".") and d not in (".i18n",))]
        for fn in fns:
            rel = os.path.relpath(os.path.join(dp, fn), repo).replace(os.sep, "/")
            if rel.startswith(("ai/", "docs/")) or re.search(r"\.(?:test|spec|stories|story|mock)\.", fn):
                continue
            hit = locate(rel, extra)
            if hit:
                found.append((rel,) + hit)
    return found


def is_slot(key, vals):
    """An empty leaf whose siblings share its stem — `heroTitleA` / `heroTitleMid` / `heroTitleB` — is a word-order slot."""
    parent, _, leaf = key.rpartition(".")
    stem = re.sub(r"(?:Mid(?:dle)?|Infix|Between|Before|After|Prefix|Suffix|Start|End|[A-Z]|_?\d+)$", "", leaf)
    if len(stem) < 3 or stem == leaf:
        return False
    sib = [k for k in vals if k != key and k.rpartition(".")[0] == parent and k.rpartition(".")[2].startswith(stem) and vals[k]]
    return len(sib) >= 2


def used_keys(repo, roots):
    call = re.compile(r"(?<![\w$.])(?:t|\$t|\$tc|tc|i18n\.t|i18next\.t|translate|intl\.formatMessage)\(\s*"
                      r"(?:(['\"])([^'\"`\s{}$<>]+)\1|`([^`$]*)\$\{|(['\"])([\w.:-]*[.:])\4\s*\+)")
    other = re.compile(r"\bi18nKey\s*=\s*\{?\s*(['\"])([^'\"\s]+)\1|(['\"])([\w.:-]+)\3\s*\|\s*translate\b")
    uses, dyn, lits = [], [], set()
    lit = re.compile(r"(['\"`])([A-Za-z_$][\w$.:\[\]-]*)\1|[\w$-]+(?:\.[\w$-]+)+")
    tpl_prefix = re.compile(r"`(?:\$\{[^}`]+\}:|[\w-]+:)?([A-Za-z_][\w.-]*[._])\$\{")   # `ns:carrierCode.${x}` too
    ns_tpl = re.compile(r"(?<![\w$.])(?:t|\$t|i18n\.t|i18next\.t)\(\s*`\$\{[^}`]+\}:([\w.-]+)`")
    # `const KEY = 'ns:carrierReason'` … `${KEY}.jt.${code}`: a key built on a string constant (resolved after the walk)
    const_def = re.compile(r"\b(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*(?::\s*[\w$.]+\s*)?=\s*(['\"])([\w.:-]+)\2\s*(?:as\s+const\s*)?[;,\n]")
    const_tpl = re.compile(r"`\$\{\s*([A-Za-z_$][\w$]*)\s*\}((?:\.[\w-]+)*\.?)(\$\{|`)")
    dyn_head = re.compile(r"(?<![\w$.])(?:t|\$t|i18n\.t|i18next\.t)\(\s*(`\$\{\s*([A-Za-z_$][\w$]*)\s*\}\.[^`]*`)")
    skip_call = re.compile(r"(?<![\w$.])(?:t|\$t|i18n\.t|i18next\.t)\(\s*(['\"])([^'\"`\s]+)\1\s*,\s*\{[^}]*\b(?:skipInterpolation\s*:\s*true|skipOnVariables)")
    consts, local, tpls, heads, skips = {}, {}, [], [], set()
    for root in roots:
        base = os.path.join(repo, root)
        for dp, dns, fns in os.walk(base):
            dns[:] = [d for d in dns if d not in SKIP_DIRS and not d.startswith(".")]
            for fn in fns:
                if not fn.endswith(CODE_EXT) or re.search(r"\.(?:test|spec|stories|story|mock)\.", fn):
                    continue
                p = os.path.join(dp, fn)
                rel = os.path.relpath(p, repo).replace(os.sep, "/")
                try:
                    text = read_text(p)
                except OSError:
                    continue
                lits.update(m.group(2) or m.group(0) for m in lit.finditer(text))
                for m in const_def.finditer(text):
                    consts.setdefault(m.group(1), set()).add(m.group(3)); local[(rel, m.group(1))] = m.group(3)
                for ln, line in enumerate(text.splitlines(), 1):
                    if re.match(r"\s*(?://|/?\*|#|<!--)", line):
                        continue
                    for m in call.finditer(line):
                        if m.group(2):
                            uses.append((rel, ln, m.group(2)))
                        else:
                            dyn.append((rel, ln, m.group(3) if m.group(3) is not None else m.group(5)))
                    for m in ns_tpl.finditer(line):
                        uses.append((rel, ln, m.group(1))); lits.add(m.group(1))
                    for m in tpl_prefix.finditer(line):
                        lits.add("\x00" + m.group(1))
                    for m in const_tpl.finditer(line):
                        tpls.append((rel, ln, m.group(1), m.group(2), m.group(3) == "`"))
                    for m in dyn_head.finditer(line):
                        heads.append((rel, ln, m.group(2), m.group(1)))
                    for m in skip_call.finditer(line):
                        skips.add(m.group(2).split(":", 1)[-1])
                    for m in other.finditer(line):
                        uses.append((rel, ln, m.group(2) or m.group(4)))
    resolved = set()
    for rel, ln, name, rest, whole in tpls:
        val = local.get((rel, name)) or (next(iter(consts[name])) if len(consts.get(name, ())) == 1 else None)
        if not val:
            continue
        key = val.split(":", 1)[-1] + rest
        resolved.add(name)
        if whole:
            lits.add(key)
        elif key.endswith("."):
            lits.add("\x00" + key); dyn.append((rel, ln, key))
    heads = [(rel, ln, tpl) for rel, ln, name, tpl in heads if name not in resolved and not local.get((rel, name))]
    return uses, dyn, lits, heads, skips


def main(argv):
    args = {"repo": ".", "locales": None, "base": None, "used": None, "max": 40, "json": False, "v1": None}
    for a in argv:
        if a == "--self-test":
            return self_test()
        if a == "--json":
            args["json"] = True
        elif a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            if k not in args:
                die(f"unknown option --{k}")
            args[k] = int(v) if k == "max" else v
        elif a.startswith("-"):
            die(f"unknown option {a}")
        else:
            args["repo"] = a
    repo = os.path.abspath(args["repo"])
    if not os.path.isdir(repo):
        die(f"not a directory: {repo}")
    only = {l.strip() for l in args["locales"].split(",")} if args["locales"] else set()
    extra = {l.split("-")[0] for l in only}

    files = discover(repo, extra)
    sets, notes, errors = {}, set(), []
    for rel, kind, loc, sid in files:
        p = os.path.join(repo, rel)
        try:
            if kind == "xcstrings":
                per, src = parse_xcstrings(p)
                for lang, (vals, forms) in per.items():
                    sets.setdefault(("xcstrings", sid), {})[lang] = (rel, vals, forms)
                sets[("xcstrings", sid)]["_srclang"] = src
                continue
            vals, forms, note = parse(kind, p, loc)
        except (ValueError, ET.ParseError, OSError) as e:
            errors.append(f"{rel}: {type(e).__name__}: {str(e)[:120]}")
            continue
        if note:
            notes.add(note)
        if only and loc not in only and loc.split("-")[0] not in extra and not loc.startswith("_"):
            continue
        sets.setdefault((kind, sid), {})[loc] = (rel, vals, forms)

    srclang = {k: v.pop("_srclang") for k, v in sets.items() if "_srclang" in v}
    # A token that never shares a set with another locale, in a family that has multi-locale sets, is a
    # word that looks like a locale (team-hr.json → `hr`): drop it unless --locales names it.
    for fam in set(FAMILY.values()):
        fam_sets = {k: v for k, v in sets.items() if FAMILY[k[0]] == fam}
        if any(len(v) > 1 for v in fam_sets.values()):
            paired = {l for v in fam_sets.values() if len(v) > 1 for l in v}
            for k, v in fam_sets.items():
                for l in [l for l in v if l not in paired and l not in only and not l.startswith("_")]:
                    notes.add(f"ignored token `{l}` in {v[l][0]} (never paired with another locale)")
                    del v[l]
                if not v:
                    del sets[k]
    pkg_cache = {}

    def package_of(sid):
        """The nearest directory above a set (relative to the repo) holding a package.json; '' = the repo."""
        d = os.path.dirname(sid)
        while d and d not in pkg_cache:
            if os.path.isfile(os.path.join(repo, d, "package.json")):
                pkg_cache[d] = d
                break
            d = os.path.dirname(d)
        return pkg_cache.get(d, "") if d else ""

    family_locales = {}
    for (kind, sid), per in sets.items():
        family_locales.setdefault((FAMILY[kind], package_of(sid)), set()).update(per)
    all_locales = sorted({l for s in family_locales.values() for l in s if not l.startswith("_")})
    rtl = sorted(l for l in all_locales if l.split("-")[0] in RTL)
    base = args["base"] or ("en" if "en" in all_locales else (all_locales[0] if all_locales else None))

    findings, cands = [], []
    v1_per, v1_files, v1_notes = v1_catalogs(os.path.abspath(args["v1"])) if args["v1"] else ({}, [], [])
    if args["v1"] and not os.path.isdir(args["v1"]):
        die(f"--v1 is not a directory: {args['v1']}")
    req, plural_src = required_forms(sorted(set(all_locales) | set(v1_per)))
    v2_index = {}
    blocked_plural = sorted(l for l in all_locales if l not in req)
    for (kind, sid), per in sorted(sets.items(), key=lambda x: x[0][1]):
        fam = FAMILY[kind]
        locs = sorted(per)
        pkg = package_of(sid)
        declared = family_locales[(fam, pkg)] if kind != "xcstrings" else set(per)
        for miss in sorted(declared - set(per)):
            if not (kind == "xlf" and miss == "_src"):
                findings.append(("missing-file", sid, miss, f"no {kind} catalog for `{miss}` (family {fam}"
                                 f"{' in ' + pkg if pkg else ''} declares it)"))
        # i18next plural keys (key_one … key_other) fold into their base, but only when some locale of the
        # set has `<base>_other` — `errors.too_many` is a key, not a plural form.
        bases = set()
        if kind in ("json", "yaml", "ts"):
            for loc in locs:
                for k in per[loc][1]:
                    m = PLURAL_SUFFIX.match(k)
                    if m and m.group(1) and m.group(2) == "other":
                        bases.add(m.group(1))
            # `errors.modified_by_other` alone is a key; a plural has a second form or a {{count}}
            def is_plural(b):
                return any(sum(1 for f in ("zero", "one", "two", "few", "many") if f"{b}_{f}" in per[l][1]) or
                           "count" in str(per[l][1].get(f"{b}_other", "")) for l in locs)
            bases = {b for b in bases if is_plural(b)}
        folded = {}
        for loc in locs:
            rel, vals, forms = per[loc]
            fk, ff = {}, {b: set(f) for b, f in forms.items()}
            for k, v in vals.items():
                m = PLURAL_SUFFIX.match(k)
                if m and m.group(1) in bases:
                    ff.setdefault(m.group(1), set()).add(m.group(2))
                    prev = fk.get(m.group(1))
                    fk[m.group(1)] = v if prev is None else (prev if v is None else prev + " | " + v)
                else:
                    fk[k] = v
            folded[loc] = (rel, fk, ff)
        if args["v1"]:
            stem_ = re.sub(r"[._-]?\{L\}[._-]?", "", os.path.splitext(os.path.basename(sid))[0])
            for loc in locs:
                for k, v in folded[loc][1].items():
                    pf = set(folded[loc][2].get(k, set()))
                    for _n, opts in placeholders(v, kind)[1].items():
                        pf |= opts
                    for kk in ({k, f"{stem_}.{k}"} if stem_ else {k}):
                        v2_index.setdefault(loc, {}).setdefault(kk, (sid, v, pf))
        if len(locs) < 2:
            continue
        src_loc = srclang.get((kind, sid)) or ("_src" if "_src" in folded else ("_default" if "_default" in folded else base))
        universe = set(folded["_src"][1]) if kind == "xlf" and "_src" in folded else set().union(*(set(f[1]) for f in folded.values()))
        for loc in locs:
            rel, fk, ff = folded[loc]
            if loc == "_src":
                continue
            for k in sorted(universe - set(fk)):
                has = [l for l in locs if k in folded[l][1] and l != loc]
                findings.append(("missing-key", sid, loc, f"{k}  (in {', '.join(has)})"))
            for k, v in sorted(fk.items()):
                filled_elsewhere = any(folded[l][1].get(k) for l in locs if l != loc)
                if v is None or (v == "" and filled_elsewhere):
                    row = (sid, loc, f"{k}  ({'empty' if v == '' else 'not translated'})")
                    findings.append(("untranslated",) + row) if v is None or not is_slot(k, fk) else cands.append(("untranslated-slot",) + row)
            # plural forms the locale needs (Intl.PluralRules), from i18next suffixes, Android/xcstrings
            # quantities and ICU plural arguments
            lang = loc if loc in req else loc.split("-")[0]
            pforms = dict(ff)
            for k, v in fk.items():
                for name, opts in placeholders(v, kind)[1].items():
                    pforms.setdefault(f"{k} {{{name}, plural}}", set()).update(opts)
            if lang in req:
                for k, have in sorted(pforms.items()):
                    gap = req[lang] - have - ({"zero"} if "=0" in have else set())
                    if gap and have:
                        findings.append(("plural-forms", sid, loc, f"{k}: has {','.join(sorted(have))}; "
                                         f"{lang} needs {','.join(sorted(req[lang]))}"))
        # placeholders and same-as-base, against the source locale of the set
        ref = folded.get(src_loc) or folded[locs[0]]
        for loc in locs:
            if loc in (src_loc, "_src"):
                continue
            rel, fk, _ = folded[loc]
            same = []
            for k, v in sorted(fk.items()):
                rv = ref[1].get(k)
                if v is None or rv is None:
                    continue
                pa, pb = placeholders(rv, kind)[0], placeholders(v, kind)[0]
                if pa != pb:
                    row = (sid, loc, f"{k}: {src_loc} {' '.join(pa) or '—'} · {loc} {' '.join(pb) or '—'}")
                    lone = all(re.fullmatch(r"\s*(?:\{\{[^{}]+\}\}|\{[^{},]+\}|%(?:\d+\$)?[sd@])\s*", s) for s in (rv, v))
                    (cands if lone else findings).append(("placeholder-token" if lone else "placeholder",) + row)
                # multi-word text left in the source language; single tokens are usually names, units or keys
                if v == rv and re.search(r"[^\W\d_]{2,}\s+[^\W\d_]{2,}", v) and loc.split("-")[0] != str(src_loc).split("-")[0]:
                    same.append(k)
            if same:
                cands.append(("same-as-base", sid, loc, f"{len(same)} value(s) identical to {src_loc} (first: {', '.join(same[:3])})"))

    v1_out = []
    if args["v1"]:
        matched, unmapped = 0, {}
        for loc in sorted(v1_per):
            idx = v2_index.get(loc) or v2_index.get(loc.split("-")[0]) or {}
            lang = loc if loc in req else loc.split("-")[0]
            for k, v in sorted(v1_per[loc].items()):
                sid1 = "v1:" + k.split(".", 1)[0] if "." in k and not k.endswith(".") else "v1:json"
                hit = idx.get(k)
                pl = lv_plural(v)
                if pl and pl[1]:
                    cands.append(("v1-plural-range", sid1, loc, f"{k}: V1 picks a form by number range "
                                  f"({' | '.join(LV_RANGE.match(p).group(1) for p in pl[0] if LV_RANGE.match(p))}); "
                                  "CLDR categories cannot express a range — read the V2 key at counts 0,1,2,3,11,100 (V369)"))
                if hit is None:
                    unmapped.setdefault(loc, []).append(k); continue
                matched += 1
                v2sid, v2val, v2forms = hit
                ph1 = {x.lower() for x in LV_PH.findall(v or "")}
                ph2 = {re.sub(r"^\{\{|\}\}$|^\{|\}$|^%\{|^%\(|\)$", "", x).strip().lower()
                       for x in placeholders(v2val, "json")[0] if x.startswith(("{", "%{", "%("))}
                if ph1 != ph2 and not (pl and ph1 - {"count"} == ph2 - {"count"}):
                    findings.append(("v1-placeholder", sid1, loc, f"{k}: V1 {' '.join(':' + x for x in sorted(ph1)) or '—'}"
                                     f" · V2 {' '.join(sorted(ph2)) or '—'} ({v2sid})"))
                if pl:
                    if v2forms:
                        gap = (req.get(lang, set()) - v2forms - ({"zero"} if "=0" in v2forms else set()))
                        if gap:
                            findings.append(("v1-plural-forms", sid1, loc, f"{k}: V1 has {len(pl[0])} Laravel form(s); "
                                             f"V2 {v2sid} has {','.join(sorted(v2forms))}; {lang} needs "
                                             f"{','.join(sorted(req[lang]))}"))
                    elif pl[1] or "count" in ph1 or len(pl[0]) >= 3:
                        findings.append(("v1-plural-lost", sid1, loc, f"{k}: V1 is a {len(pl[0])}-form "
                                         f"{'range ' if pl[1] else ''}plural; V2 {v2sid} has one form (no _one/_other "
                                         "suffix, no ICU plural)"))
                    else:
                        cands.append(("v1-pipe-text", sid1, loc, f"{k}: a `|` in a 2-part value with no :count — "
                                      "a plural or a literal pipe? read how V1 calls it (trans_choice vs __)"))
        for loc, ks in sorted(unmapped.items()):
            cands.append(("v1-unmapped", "v1", loc, f"{len(ks)} V1 key(s) with no V2 key of the same name "
                          f"(first: {', '.join(ks[:5])}) — renamed (pair-map row) or dropped?"))
        v1_out = [f"v1 cross-tree: {len(v1_files)} V1 lang file(s), "
                  f"{sum(len(x) for x in v1_per.values())} key(s) in {', '.join(sorted(v1_per)) or 'no locale'}; "
                  f"{matched} matched a V2 key by name or file-namespaced name"] + v1_notes
        if not v1_files:
            v1_out.append("v1 cross-tree: blocked (no lang/ or resources/lang/ under --v1)")

    used_out = []
    if args["used"] is not None and all_locales:
        roots = [os.path.normpath(r) for r in args["used"].split(",") if r] or ["."]
        uses, dyn, lits, heads, skips = used_keys(repo, roots)
        # a key read with skipInterpolation renders its {{token}} literally: not an argument mismatch
        for f in [f for f in findings if f[0] == "placeholder" and f[3].split(":", 1)[0] in skips]:
            findings.remove(f); cands.append(("placeholder-token",) + f[1:3] + (f[3] + "  (read with skipInterpolation)",))

        def spans(key):
            parts = re.sub(r"\[(\d+)\]", r".\1", key).split(".")
            return {".".join(parts[i:j]) for i in range(len(parts)) for j in range(i + 1, len(parts) + 1)}

        # Every contiguous dotted span of every catalog key, under the namespaces a loader plausibly mounts
        # it at (the file stem, and its parent directory + stem: docs/banner.en.json → `docs.banner.…`).
        # Spans cover t('a.b', { returnObjects: true }) on an object or array, and i18next's dotted indices.
        known_set = set()
        for (kind, sid), per in sets.items():
            stem = re.sub(r"[._-]?\{L\}[._-]?", "", os.path.splitext(os.path.basename(sid))[0])
            parent = os.path.basename(os.path.dirname(sid)).replace("{L}", "")
            nss = [""] + ([stem] if stem else []) + ([f"{parent}.{stem}"] if stem and parent and parent not in ("i18n", "locales", "lang") else [])
            for loc, (rel, vals, forms) in per.items():
                for k in vals:
                    m = PLURAL_SUFFIX.match(k)
                    b0 = m.group(1) if m and m.group(1) else k
                    for ns in nss:
                        known_set |= spans(f"{ns}.{b0}" if ns else b0)
        seen = set()
        for rel, ln, k in uses:
            if k.split(":", 1)[-1] not in known_set and (rel, k) not in seen:
                seen.add((rel, k)); findings.append(("used-undefined", f"{rel}:{ln}", "-", f"t('{k}') — in no catalog under any namespace"))
        prefixes = {}
        for rel, ln, p in dyn:
            p2 = (p or "").split(":", 1)[-1]
            if p2 and p2 not in prefixes:
                prefixes[p2] = (rel, ln, sum(1 for k in known_set if k.startswith(p2) and "." not in k[len(p2):]))
        for p, (rel, ln, cnt) in sorted(prefixes.items()):
            cands.append(("dynamic-prefix", f"{rel}:{ln}", "-", f"`{p}${{…}}` — {cnt} catalog key(s) under it; cross with the variable's bound"))
        for rel, ln, tpl in sorted(set(heads)):
            cands.append(("dynamic-prefix", f"{rel}:{ln}", "-", f"{tpl} — <fully dynamic> head: read the variable's bound; keys under it are not credited"))
        if base:
            ref_spans = set()
            for lit in lits:
                if not lit.startswith("\x00"):
                    ref_spans |= spans(lit.split(":", 1)[-1])
            # every key-shaped template prefix in code (`activity_entity_${x}`), not only those inside t(
            ptuple = tuple({p for p in prefixes if p} | {l[1:] for l in lits if l.startswith("\x00")})
            unused = set()
            for (kind, sid), per in sets.items():
                if base not in per or not any(r in (".", "") or sid.startswith(r.rstrip("/") + "/") for r in roots):
                    continue
                stem = re.sub(r"[._-]?\{L\}[._-]?", "", os.path.splitext(os.path.basename(sid))[0])
                parent = os.path.basename(os.path.dirname(sid)).replace("{L}", "")
                for k in per[base][1]:
                    m = PLURAL_SUFFIX.match(k)
                    b0 = re.sub(r"\[(\d+)\]", r".\1", m.group(1) if m and m.group(1) else k)
                    # a top-level namespace object (`{ common: {…} }` loaded as ns `common`) is dropped too
                    forms = [b0, b0.split(".", 1)[-1]] + ([f"{stem}.{b0}", f"{parent}.{stem}.{b0}"] if stem else [])
                    def referenced(f):
                        segs = f.split(".")
                        return (f in ref_spans or (ptuple and f.startswith(ptuple))
                                or any(".".join(segs[:i]) in ref_spans for i in range(2, len(segs))))
                    if not any(referenced(f) for f in forms):
                        unused.add(f"{sid} :: {b0}")
            for u in sorted(unused)[: args["max"]]:
                cands.append(("unused-key", u.split(" :: ")[0], base, u.split(" :: ")[1]))
            if len(unused) > args["max"]:
                cands.append(("unused-key", "…", base, f"{len(unused) - args['max']} more (raise --max)"))
        used_out = [f"used keys scanned: {len(uses)} literal, {len(dyn)} dynamic, roots {','.join(roots)}"]

    gate = ("OFF — no catalog with a locale token (single-locale or no i18n layer; see i18n-scan § The locale-count gate)"
            if not all_locales else
            f"ON — {len(all_locales)} locales" if len(all_locales) > 1 else
            f"CATALOG-ONLY — one locale ({all_locales[0]})")
    summary = {}
    for f in findings:
        summary[f[0]] = summary.get(f[0], 0) + 1
    if args["json"]:
        print(json.dumps({"gate": gate, "locales": all_locales, "rtl": rtl, "base": base, "files": len(files),
                          "sets": len(sets), "plural_rules": plural_src, "plural_blocked": blocked_plural,
                          "findings": [dict(zip(("class", "set", "locale", "detail"), f)) for f in findings],
                          "candidates": [dict(zip(("class", "set", "locale", "detail"), c)) for c in cands],
                          "errors": errors, "notes": sorted(notes) + v1_out}, ensure_ascii=False, indent=1))
    else:
        kinds = {}
        for _, kind, _, _ in files:
            kinds[kind] = kinds.get(kind, 0) + 1
        print(f"catalog-parity — {len(files)} catalog files in {len(sets)} sets ({', '.join(f'{k} {v}' for k, v in sorted(kinds.items()))})")
        print(f"LOCALES: {', '.join(all_locales) or 'none'} · RTL: {', '.join(rtl) or 'none'} · base: {base or '—'}")
        print(f"GATE: {gate}")
        print(f"plural rules: {plural_src}" + (f" · plural-check: blocked for {', '.join(blocked_plural)}" if blocked_plural else ""))
        for n in sorted(notes) + used_out + v1_out:
            print(f"note: {n}")
        for e in errors:
            print(f"read-error: {e}")
        shown = {}
        for cls, sid, loc, detail in findings + cands:
            shown[cls] = shown.get(cls, 0) + 1
            if shown[cls] <= args["max"]:
                print(f"{cls:<15} {sid}  [{loc}]  {detail}")
            elif shown[cls] == args["max"] + 1:
                print(f"{cls:<15} … more not shown (raise --max)")
        print("SUMMARY: " + (" · ".join(f"{k} {v}" for k, v in sorted(summary.items())) or "no findings")
              + (" · candidates " + str(len(cands)) if cands else "") + (f" · read errors {len(errors)}" if errors else ""))
    return 2 if errors and not sets else (1 if findings else 0)


def self_test():
    d = tempfile.mkdtemp(prefix="catalog-parity-")
    def w(rel, text):
        p = os.path.join(d, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w", encoding="utf-8").write(text)
    # 2026-10-15 rows: a key built on a string constant and on an `ns:` literal head are referenced; a lone display
    # token and a skipInterpolation key are placeholder-token candidates; an empty A/Mid/B sibling is a slot
    extra_en = {"reason": {"jt": {"a": "A"}}, "code": {"x": {"y": "Y"}}, "tok": "{{variable}}", "raw": "Hi {{name}}",
                "hero": {"heroTitleA": "Fast", "heroTitleMid": "", "heroTitleB": "shipping"}, "dead": "Dead"}
    extra_ar = {"reason": {"jt": {"a": "أ"}}, "code": {"x": {"y": "ي"}}, "tok": "{{متغير}}", "raw": "مرحبا {{اسم}}",
                "hero": {"heroTitleA": "شحن", "heroTitleMid": "سريع", "heroTitleB": "جدا"}, "dead": "ميت"}
    w("src/locales/en.json", json.dumps({"a": {"b": "Save {{name}}"}, "items_one": "{{count}} item", "items_other": "{{count}} items", "only_en": "x", **extra_en}))
    w("src/locales/ar.json", json.dumps({"a": {"b": "احفظ"}, "items_one": "عنصر", "items_other": "{{count}} عناصر", **extra_ar}))
    w("src/i18n/en/errors.json", json.dumps({"e": "Boom"}))
    w("app/src/main/res/values/strings.xml", '<resources><string name="hi">Hi %1$s</string><string name="v" translatable="false">1</string></resources>')
    w("app/src/main/res/values-ar/strings.xml", '<resources><string name="hi">مرحبا</string></resources>')
    w("src/App.tsx", "t('a.b'); t('nope.key'); t(`status.${s}`)\nconst KEY = 'app:reason';\nconst l = `${KEY}.jt.${c}`;\n"
      "const m = `app:code.${f}.${g}`;\nt('raw', { skipInterpolation: true }); t('tok'); t('hero.heroTitleA');\nt(`${group}.${k}.label`)")
    # two apps of a monorepo with different locale sets: neither is told it lacks the other's locale
    w("apps/one/package.json", "{}"); w("apps/one/locales/en.json", '{"k": "K"}'); w("apps/one/locales/de.json", '{"k": "K2"}')
    w("apps/two/package.json", "{}"); w("apps/two/messages/en.json", '{"k": "K"}'); w("apps/two/messages/ar.json", '{"k": "ك"}')
    out = subprocess.run([sys.executable, __file__, d, "--used=src", "--json"], capture_output=True, text=True)
    r = json.loads(out.stdout)
    got = {(f["class"], f["detail"].split()[0].rstrip(":")) for f in r["findings"]}
    expect = {("missing-key", "only_en"), ("placeholder", "a.b"), ("missing-file", "no"), ("placeholder", "hi"),
              ("plural-forms", "items"), ("used-undefined", "t('nope.key')")}
    cross = [f for f in r["findings"] if f["class"] == "missing-file" and f["set"].startswith("apps/")]
    cand = {(c["class"], c["detail"].split()[0].rstrip(":")) for c in r["candidates"]}
    unused = {c["detail"] for c in r["candidates"] if c["class"] == "unused-key"}
    want = [("placeholder-token tok", ("placeholder-token", "tok") in cand),
            ("placeholder-token raw (skipInterpolation)", ("placeholder-token", "raw") in cand and ("placeholder", "raw") not in got),
            ("untranslated-slot hero.heroTitleMid", ("untranslated-slot", "hero.heroTitleMid") in cand and ("untranslated", "hero.heroTitleMid") not in got),
            ("const-prefix key referenced (reason.jt.a)", "reason.jt.a" not in unused),
            ("ns-literal template key referenced (code.x.y)", "code.x.y" not in unused),
            ("unreferenced key still unused (dead)", "dead" in unused),
            ("fully dynamic head printed", any("<fully dynamic>" in c["detail"] for c in r["candidates"]))]
    ok = expect <= got and not cross and out.returncode == 1 and r["locales"] == ["ar", "de", "en"] and all(v for _, v in want)
    for name, v in want:
        print(("  ok   " if v else "  FAIL ") + name)
    print(("  ok   " if not cross else "  FAIL ") + "no cross-package missing-file" + "".join(f" ({f['set']} {f['locale']})" for f in cross))
    import shutil; shutil.rmtree(d, ignore_errors=True)
    for e in sorted(expect):
        print(("  ok   " if e in got else "  FAIL ") + " ".join(e))
    # cross-tree: a Laravel V1 lang/ against a V2 i18next tree
    v1, v2 = tempfile.mkdtemp(prefix="catalog-parity-v1-"), tempfile.mkdtemp(prefix="catalog-parity-v2-")
    def w2(root, rel, text):
        p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w", encoding="utf-8").write(text)
    php = ("<?php\n// a comment: 'ghost' => 'x',\nreturn [\n    'welcome' => 'Welcome, :name',\n"
           "    'apples' => '{0} No apples|[1,19] Some apples|[20,*] Many apples',\n    'items' => ':count item|:count items',\n"
           "    'title' => 'Home | Site',\n    'nested' => ['deep' => 'Deep :thing'],\n    'time' => 'Opens at 10:30',\n"
           "    'gone' => 'Gone',\n    'joined' => 'Hello ' . 'there',\n    'dyn' => __('x'),\n];\n")
    w2(v1, "lang/en/messages.php", php)
    w2(v1, "lang/ar/messages.php", php.replace("':count item|:count items'", "':count عنصر|:count عناصر'").replace("'Welcome, :name'", "'أهلا :Name'"))
    w2(v1, "lang/en.json", json.dumps({"Save": "Save"})); w2(v1, "lang/ar.json", json.dumps({"Save": "احفظ"}))
    v2en = {"welcome": "Welcome, {{name}}", "items_one": "{{count}} item", "items_other": "{{count}} items", "apples": "Apples",
            "title": "Home | Site", "nested": {"deep": "Deep {{other}}"}, "time": "Opens at 10:30", "joined": "Hello there", "Save": "Save"}
    w2(v2, "src/locales/en/messages.json", json.dumps(v2en))
    w2(v2, "src/locales/ar/messages.json", json.dumps(dict(v2en, welcome="أهلا {{name}}")))
    out2 = subprocess.run([sys.executable, __file__, v2, "--v1=" + v1, "--json"], capture_output=True, text=True)
    r2 = json.loads(out2.stdout)
    shutil.rmtree(v1, ignore_errors=True); shutil.rmtree(v2, ignore_errors=True)
    f2 = {(f["class"], f["locale"], f["detail"].split(":")[0]) for f in r2["findings"]}
    c2 = {(c["class"], c["locale"], c["detail"].split(":")[0]) for c in r2["candidates"]}
    unm = " ".join(c["detail"] for c in r2["candidates"] if c["class"] == "v1-unmapped")
    want2 = [("v1-plural-forms ar messages.items (ar needs six CLDR forms)", ("v1-plural-forms", "ar", "messages.items") in f2),
             ("no v1-plural-forms for en messages.items (one,other suffice)", ("v1-plural-forms", "en", "messages.items") not in f2),
             ("v1-plural-lost en messages.apples (range plural, one V2 form)", ("v1-plural-lost", "en", "messages.apples") in f2),
             ("v1-plural-range candidate messages.apples", ("v1-plural-range", "en", "messages.apples") in c2),
             ("v1-pipe-text candidate, not a finding: messages.title", ("v1-pipe-text", "en", "messages.title") in c2
              and not any(x[2] == "messages.title" for x in f2)),
             ("v1-placeholder messages.nested.deep (:thing vs {{other}})", ("v1-placeholder", "en", "messages.nested.deep") in f2),
             (":Name matches {{name}}; 10:30 is not a placeholder", not any(x[0] == "v1-placeholder" and x[2] in ("messages.welcome", "messages.time") for x in f2)),
             ("v1-unmapped lists messages.gone; JSON key Save and a concatenation matched", "messages.gone" in unm and "Save" not in unm and "messages.joined" not in unm),
             ("a commented PHP entry and a non-literal value are not keys", "ghost" not in unm and "messages.dyn" not in unm),
             ("exit 1 on cross-tree findings", out2.returncode == 1)]
    for name, v in want2:
        print(("  ok   " if v else "  FAIL ") + name)
    ok = ok and all(v for _, v in want2)
    print("catalog-parity --self-test " + ("OK" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

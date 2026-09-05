#!/usr/bin/env bash
# lint-schema-conformance.sh — the shipped schemas must describe the shipped files.
#
# WHY. templates/schemas/claude-code/*.schema.json looked like a contract and was decorative:
# nothing anywhere read them. Measured the day this gate was written, against the schemas as
# they then stood:
#
#   commands.schema.json   185 files —  61 over description maxLength=300, 86 carrying keys
#                                       it declared forbidden (additionalProperties:false)
#   agents.schema.json     123 files —  54 over maxLength=400, 7 with forbidden keys
#
# So the schemas described a repo that never existed. That is worse than having none: a
# contributor who reads `additionalProperties:false` and drops `pack:` from a command is
# following a rule the whole repo breaks. The fix is both halves — the schemas were corrected
# to describe reality (the keys are real conventions; the length caps moved out to be a budget
# question rather than a shape one), and this gate makes them true from now on.
#
# Validates: both baseline .claude/settings.json templates against settings.schema.json, and
# every command / agent / SKILL.md frontmatter against its own schema.
#
# There is no jsonschema module on this machine, so this implements the SUBSET the repo's
# schemas actually use: type, enum, required, properties, additionalProperties, items,
# minLength, pattern, oneOf. An unknown keyword is ignored rather than silently passing a
# file — see check_unsupported() below, which fails if a schema starts using one.
#
# Usage:   lint-schema-conformance.sh [--repo-root=<dir>] [--quiet]
# Exit:    1 on any violation; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$REPO_ROOT" QUIET="$QUIET" python3 <<'PY'
import os, re, sys, json, glob

ROOT  = os.environ["REPO_ROOT"]
QUIET = os.environ["QUIET"] == "1"
def out(m):
    if not QUIET: print(m)

errors = []
def fail(m): errors.append(m); out("\033[31m✗ %s\033[0m" % m)

SUPPORTED = {"$schema","$id","title","description","type","enum","required","properties",
             "additionalProperties","items","minLength","maxLength","pattern","oneOf",
             "minItems","maxItems","minimum","maximum","const","$defs","$ref"}

def check_unsupported(schema, where):
    """A schema keyword this validator cannot evaluate must not read as 'passed'."""
    if not isinstance(schema, dict): return
    for k in schema:
        if k not in SUPPORTED:
            fail("%s: schema uses keyword `%s`, which this validator does not implement — "
                 "it would pass silently" % (where, k))
    for k in ("properties", "$defs"):
        for sub in (schema.get(k) or {}).values(): check_unsupported(sub, where)
    for k in ("items",):
        if isinstance(schema.get(k), dict): check_unsupported(schema[k], where)
    for sub in schema.get("oneOf") or []: check_unsupported(sub, where)
    ap = schema.get("additionalProperties")
    if isinstance(ap, dict): check_unsupported(ap, where)

TYPES = {"object": dict, "array": list, "string": str, "boolean": bool,
         "number": (int, float), "integer": int}

ROOT_SCHEMA = {}

def validate(inst, schema, path, label):
    if "$ref" in schema:
        ref = schema["$ref"]
        if ref.startswith("#/$defs/"):
            target = (ROOT_SCHEMA.get("$defs") or {}).get(ref.split("/")[-1])
            if target is None:
                fail("%s: %s refers to %s, which is not defined" % (label, path, ref)); return
            return validate(inst, target, path, label)
        return
    t = schema.get("type")
    if t:
        py = TYPES.get(t)
        if py and not isinstance(inst, py) or (t == "number" and isinstance(inst, bool)):
            fail("%s: %s should be %s, got %s" % (label, path or "<root>", t, type(inst).__name__))
            return
    if "oneOf" in schema:
        if not any(_ok(inst, s) for s in schema["oneOf"]):
            fail("%s: %s matches none of the allowed shapes" % (label, path))
        return
    if "enum" in schema and inst not in schema["enum"]:
        fail("%s: %s is %r, not one of %s" % (label, path, inst, schema["enum"])); return
    if isinstance(inst, str):
        if "minLength" in schema and len(inst) < schema["minLength"]:
            fail("%s: %s is shorter than minLength=%d" % (label, path, schema["minLength"]))
        if "maxLength" in schema and len(inst) > schema["maxLength"]:
            fail("%s: %s is %d chars, over maxLength=%d" % (label, path, len(inst), schema["maxLength"]))
        if "pattern" in schema and not re.search(schema["pattern"], inst):
            fail("%s: %s = %r does not match %s" % (label, path, inst[:40], schema["pattern"]))
    if isinstance(inst, dict):
        props = schema.get("properties") or {}
        for r in schema.get("required") or []:
            if r not in inst: fail("%s: missing required key `%s`" % (label, r))
        ap = schema.get("additionalProperties", True)
        for k, v in inst.items():
            if k in props: validate(v, props[k], (path + "." if path else "") + k, label)
            elif ap is False: fail("%s: key `%s` is not allowed by the schema" % (label, k))
            elif isinstance(ap, dict): validate(v, ap, (path + "." if path else "") + k, label)
    if "const" in schema and inst != schema["const"]:
        fail("%s: %s is %r, must be %r" % (label, path, inst, schema["const"])); return
    if isinstance(inst, (int, float)) and not isinstance(inst, bool):
        if "minimum" in schema and inst < schema["minimum"]:
            fail("%s: %s is below minimum=%s" % (label, path, schema["minimum"]))
        if "maximum" in schema and inst > schema["maximum"]:
            fail("%s: %s is above maximum=%s" % (label, path, schema["maximum"]))
    if isinstance(inst, list):
        if "minItems" in schema and len(inst) < schema["minItems"]:
            fail("%s: %s has %d item(s), minItems=%d" % (label, path, len(inst), schema["minItems"]))
        if "maxItems" in schema and len(inst) > schema["maxItems"]:
            fail("%s: %s has %d item(s), maxItems=%d" % (label, path, len(inst), schema["maxItems"]))
    if isinstance(inst, list) and isinstance(schema.get("items"), dict):
        for i, v in enumerate(inst):
            validate(v, schema["items"], "%s[%d]" % (path, i), label)

def _ok(inst, schema):
    before = len(errors)
    validate(inst, schema, "", "<probe>")
    ok = len(errors) == before
    del errors[before:]
    return ok

def frontmatter(f):
    """key -> value, with continuation lines folded into the previous key."""
    txt = open(f, encoding="utf-8").read().split("\n")
    if not txt or txt[0].strip() != "---": return None
    d, key = {}, None
    for line in txt[1:]:
        if line.strip() == "---": break
        if line.lstrip().startswith("#"): continue      # YAML comment, not a continuation
        m = re.match(r"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t](.*))?$", line)
        if m:
            key = m.group(1); d[key] = (m.group(2) or "")
        elif key is not None:
            d[key] += "\n" + line
    for k, v in list(d.items()):
        s = v.strip()
        if s in ("true", "false"): d[k] = (s == "true")
        else: d[k] = v.strip()
    return d

def load(p):
    try: return json.load(open(os.path.join(ROOT, p), encoding="utf-8"))
    except Exception as e:
        fail("cannot read schema %s: %s" % (p, e)); return None

SD = "templates/schemas/claude-code"
schemas = {k: load("%s/%s.schema.json" % (SD, k)) for k in
           ("settings", "commands", "agents", "skills")}
for k, s in schemas.items():
    if s: check_unsupported(s, "%s.schema.json" % k)

def g(*pats):
    """Files matching pats under ROOT, skipping this repo's OWN tests/ tree.

    The skip is computed RELATIVE to ROOT. As a substring match on the absolute path it
    also skipped every file when ROOT itself lived under a directory called tests — which
    is exactly where the fixture harness puts it, so all three bad fixtures found zero
    files and the gate reported clean."""
    seen = []
    for p in pats:
        for f in sorted(glob.glob(os.path.join(ROOT, p), recursive=True)):
            rel = os.path.relpath(f, ROOT)
            if rel.split(os.sep)[0] == "tests" or f in seen: continue
            seen.append(f)
    return seen

n = 0
for f in g("templates/repo-baseline/.claude/settings.json",
           "templates/workspace-baseline/.claude/settings.json",
           "settings.json"):
    if not schemas["settings"]: break
    try: inst = json.load(open(f, encoding="utf-8"))
    except Exception as e: fail("%s: invalid JSON — %s" % (f, e)); continue
    n += 1; ROOT_SCHEMA = schemas["settings"]
    validate(inst, schemas["settings"], "", os.path.relpath(f, ROOT))

for key, pats in (("commands", ("commands/*.md", "templates/**/commands/*.md")),
                  ("agents",   ("templates/**/agents/*.md",)),
                  ("skills",   ("templates/packs/*/skills/*/SKILL.md",))):
    if not schemas[key]: continue
    for f in g(*pats):
        fm = frontmatter(f)
        if fm is None: fail("%s: no YAML frontmatter" % os.path.relpath(f, ROOT)); continue
        n += 1; ROOT_SCHEMA = schemas[key]
        validate(fm, schemas[key], "", os.path.relpath(f, ROOT))

if errors:
    out("\033[31mschema-conformance: %d violation(s)\033[0m" % len(errors)); sys.exit(1)
out("\033[32m✓ schema conformance: %d file(s) match the schema they ship under\033[0m" % n)
sys.exit(0)
PY

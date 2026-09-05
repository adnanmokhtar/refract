#!/usr/bin/env bash
# lint-mcp-catalog.sh — every server detect-mcp.sh WRITES must still be installable.
#
# WHY. detect-mcp.sh's header already refuses to emit a package whose name is unknown:
# `"args": ["-y","<TODO: …>"]` is "configuration that looks valid and fails at startup,
# which is strictly worse than an absent entry". That rule had no mechanism behind it, and
# it only ever covered packages that were unknown when they were WRITTEN — not packages
# that stopped existing afterwards. Both happened:
#
#   @figma/mcp                                404 on the registry — never existed
#   @mobile-next/mcp                          404 — the project publishes @mobilenext/mobile-mcp
#   @modelcontextprotocol/server-github       npm: "no longer supported" (and written to
#                                             EVERY project, since github is a universal rec)
#   @modelcontextprotocol/server-puppeteer    npm: "no longer supported"
#
# Three rules:
#   1. DECLARED   — every wired `add_rec` id appears in the REGISTRY table below. A new
#                   server cannot be added without saying where it is published, because
#                   that is the fact this gate needs in order to check it at all.
#   2. RESOLVES   — the package exists in its registry. A definitive 404 fails the build.
#   3. MAINTAINED — npm's `deprecated` flag fails the build, unless the package is listed in
#                   KNOWN_DEPRECATED with a reason. Allowlisted entries are PRINTED on every
#                   run, so "we know" stays visible instead of decaying into "we forgot".
#
# Network: a timeout, DNS failure or 5xx SKIPS that probe and never fails the run — only a
# definitive answer from the registry is allowed to redden a build. `--offline` skips all
# probes and checks rule 1 only.
#
# Usage:   lint-mcp-catalog.sh [--offline] [--quiet]
# Exit:    1 on any violation; 0 otherwise.

set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
OFFLINE=0; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    --offline) OFFLINE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

CATALOG="$REPO_ROOT/scripts/detect-mcp.sh"
[ -f "$CATALOG" ] || { [ "$QUIET" = 1 ] || echo "no detect-mcp.sh under $REPO_ROOT — nothing to check"; exit 0; }

OFFLINE="$OFFLINE" QUIET="$QUIET" CATALOG="$CATALOG" python3 <<'PY'
import os, re, sys, json, urllib.request, urllib.error

OFFLINE = os.environ["OFFLINE"] == "1"
QUIET   = os.environ["QUIET"] == "1"
CATALOG = os.environ["CATALOG"]

# Rule 1's table: where each wired server is published. Adding a server to detect-mcp.sh
# without adding it here fails the gate by design.
REGISTRY = {
    "filesystem": "npm", "migration-fs": "npm", "playwright": "npm", "storybook": "npm",
    "figma": "npm", "postgres": "npm", "mysql": "npm", "mongodb": "npm",
    "mobile": "npm", "trello": "npm", "jira": "npm", "linear": "npm",
    "redis": "pypi",
    "github": "ghcr",
    "terraform": "dockerhub",
}

# Deprecated upstream, knowingly still shipped. Each entry is printed on every run so
# "we know" cannot decay into "we forgot". EMPTY is the correct state: the one entry that
# lived here (@modelcontextprotocol/server-postgres) was replaced once a successor with a
# documented invocation was found, which is what the note demanded.
KNOWN_DEPRECATED = {}

def out(msg):
    if not QUIET: print(msg)

errors = []
def fail(m): errors.append(m); out("\033[31m✗ %s\033[0m" % m)

src = open(CATALOG, encoding="utf-8").read()
wired = re.findall(r'^\s*add_rec "([a-z-]+)" "([^"]+)" "([^"]+)"', src, re.M)
if not wired:
    fail("parsed 0 wired `add_rec` rows out of detect-mcp.sh — the catalog shape changed and this gate went blind")

def get_json(url, timeout=12):
    """(payload, 'ok') | (None, 'missing') | (None, 'skip:<why>')"""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.load(r), "ok"
    except urllib.error.HTTPError as e:
        if e.code == 404: return None, "missing"
        return None, "skip:HTTP %s" % e.code
    except Exception as e:
        return None, "skip:%s" % type(e).__name__

def probe_oci(host, repo, auth):
    tok, st = get_json(auth)
    if st != "ok": return None, st
    req = urllib.request.Request(
        "https://%s/v2/%s/manifests/latest" % (host, repo),
        headers={"Authorization": "Bearer " + tok.get("token", ""),
                 "Accept": "application/vnd.oci.image.index.v1+json,"
                           "application/vnd.docker.distribution.manifest.list.v2+json"})
    try:
        with urllib.request.urlopen(req, timeout=12) as r:
            r.read(1); return {}, "ok"
    except urllib.error.HTTPError as e:
        return (None, "missing") if e.code == 404 else (None, "skip:HTTP %s" % e.code)
    except Exception as e:
        return None, "skip:%s" % type(e).__name__

checked = skipped = 0
seen_ids = set()
for rid, name, pkg in wired:
    if rid in seen_ids and REGISTRY.get(rid): pass
    seen_ids.add(rid)

    # Rule 1
    reg = REGISTRY.get(rid)
    if reg is None:
        fail("%s (%s): not in this gate's REGISTRY table — declare where it is published" % (rid, pkg))
        continue
    if OFFLINE:
        continue

    # Rules 2 + 3
    if reg == "npm":
        data, st = get_json("https://registry.npmjs.org/" + pkg)
        if st == "missing":
            fail("%s: npm has no package `%s` — `npx -y %s` fails at startup" % (rid, pkg, pkg))
            continue
        if st != "ok":
            skipped += 1; out("  skip %-13s %s (%s)" % (rid, pkg, st[5:])); continue
        latest = data.get("dist-tags", {}).get("latest")
        dep = (data.get("versions", {}).get(latest) or {}).get("deprecated")
        if dep and pkg not in KNOWN_DEPRECATED:
            fail("%s: npm marks `%s` deprecated — %s" % (rid, pkg, str(dep)[:80]))
            continue
        checked += 1
    elif reg == "pypi":
        _, st = get_json("https://pypi.org/pypi/%s/json" % pkg)
        if st == "missing": fail("%s: PyPI has no package `%s`" % (rid, pkg)); continue
        if st != "ok": skipped += 1; out("  skip %-13s %s (%s)" % (rid, pkg, st[5:])); continue
        checked += 1
    elif reg in ("ghcr", "dockerhub"):
        repo = pkg.split("/", 1)[1] if pkg.startswith("ghcr.io/") else pkg
        if reg == "ghcr":
            host, auth = "ghcr.io", "https://ghcr.io/token?scope=repository:%s:pull&service=ghcr.io" % repo
        else:
            host = "registry-1.docker.io"
            auth = ("https://auth.docker.io/token?service=registry.docker.io"
                    "&scope=repository:%s:pull" % repo)
        _, st = probe_oci(host, repo, auth)
        if st == "missing": fail("%s: no image `%s`" % (rid, pkg)); continue
        if st != "ok": skipped += 1; out("  skip %-13s %s (%s)" % (rid, pkg, st[5:])); continue
        checked += 1

for pkg, why in KNOWN_DEPRECATED.items():
    out("\033[33m  known-deprecated %s — %s\033[0m" % (pkg, why))

if errors:
    out("\033[31mmcp-catalog: %d violation(s)\033[0m" % len(errors)); sys.exit(1)
if OFFLINE:
    out("\033[32m✓ mcp catalog: %d wired server(s), every one declares its registry (offline)\033[0m" % len(wired))
else:
    out("\033[32m✓ mcp catalog: %d/%d wired server(s) resolve and are maintained (%d probe(s) skipped)\033[0m"
        % (checked, len(wired), skipped))
sys.exit(0)
PY

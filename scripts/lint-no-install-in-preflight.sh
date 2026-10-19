#!/usr/bin/env bash
# lint-no-install-in-preflight.sh — a read-only audit never downloads or installs a tool.
#
# WHY. Phase-6 benchmark runs (2026-10-19) watched two audit pre-flights reach the network:
# duplication-scan ran `npx -y jscpd@5` and a11y-code-scan ran `npm i eslint@9 eslint-plugin-jsx-a11y…`
# into $TMPDIR. An audit the owner started as "read-only" fetched and executed third-party packages,
# wrote a cache under $HOME, and its result depended on the registry's state that minute. Nothing
# flagged it: every rg gate parses the command, none asks what the command DOES.
#
# RULE. In a command, skill, agent or snippet an agent is told to RUN (a fenced shell block, or an
# inline code span), the forms below are an install or a download and may not appear in an audit:
#   npx -y / --yes / -p <pkg> / <pkg>@<ver>, pnpm dlx, yarn dlx, bunx, pnpx, npm i|install <pkg>
#   (or --prefix / -g), pip install, pipx run|install, uvx, uv tool run|install, go install,
#   go run <mod>@<ver>, cargo install, gem install, brew install, curl|wget … | sh,
#   docker run|pull without --pull=never.
# A pre-flight uses only what is already there (node_modules/.bin, PATH, the project's pinned tool,
# a locally present image with --pull=never). Absent → it prints
#   NOT-RUN (<tool> not installed — to enable: <exact install command>)
# and falls back to its grep / stdlib lane. An install happens only in a fix or setup command, after
# the user's word.
#
# NOT A HIT (the line is prose for the user, or text the detector SEARCHES FOR, not runs):
#   - the line carries a ledger word: NOT-RUN, NOT-INSTALLED, not installed, to enable, blocked,
#     "never …", BAD:/GOOD: (detector examples), or the match sits after `RUN ` (a Dockerfile
#     line) or `run:` (a CI step) — those are the audited project's text;
#   - the line is a search: it starts with rg / grep / a regex tuple;
#   - the file is a fix / setup / scaffold artifact (SETUP below) or project knowledge
#     (references/, ai-patterns/, phases/, repo-baseline/ai/) — installs there happen after the
#     user's word, which is the rule, not a breach of it.
# Prose outside a code span or fence is never read: telling the USER how to install is fine.
#
# BARE NPX (added 2026-10-19, leak-pass-2). A bare `npx <tool>` (no -y, no @version) resolves the
# project's local bin first and installs only when the tool is absent — but in a non-TTY shell npx
# then assumes --yes, so an agent's pre-flight on a repo without the tool downloads and runs it. In a
# SKILL or COMMAND (the artifacts that carry runnable pre-flights; agents are not scanned for this
# form) a bare `npx <tool>` is a hit; write `npx --no <tool>` (or `--no-install`), which runs only the
# installed tool and exits non-zero when it is absent, and print the NOT-RUN line with the install
# command. The same exemptions apply (setup/fix/scaffold artifacts, ledger words, searches, quoted
# text, a form named in prose).
#
# Usage:  lint-no-install-in-preflight.sh [--self-test] [--quiet] [--repo-root=<dir>]
# Exit:   1 if any hit; 0 otherwise. --self-test seeds a tree that must FAIL, then its fixed copy
#         that must PASS (fail-first).

set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SELF="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
MODE=lint; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE=self; shift ;;
    --quiet) QUIET=1; shift ;;
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ "$MODE" = self ]; then
  TD="$(mktemp -d "${TMPDIR:-/tmp}/no-install-selftest.XXXXXX")" || exit 2
  trap 'rm -rf "$TD"' EXIT
  mkdir -p "$TD/templates/packs/demo/skills/dup-scan" "$TD/templates/packs/demo/commands" "$TD/commands" \
           "$TD/templates/packs/demo/agents"
  ( cd "$TD" && git init -q . ) || exit 2
  F="$TD/templates/packs/demo/skills/dup-scan/SKILL.md"
  # The seeded defect: the two forms the benchmark caught, plus one of each other family, plus a
  # bare `npx <tool>` (installs in a non-TTY shell when the tool is absent).
  cat > "$F" <<'EOF'
# dup-scan
```bash
npx -y jscpd@5 --max-gap-lines 3 -r json -o "$D" .
npx knip --reporter json > "$D/knip.json"
L="$(mktemp -d)" && (cd "$L" && npm i --silent eslint@9 eslint-plugin-jsx-a11y@6.10.2)
```
Lane: `uvx ruff check --select B .` · `docker run --rm -i hadolint/hadolint hadolint - < Dockerfile`
EOF
  printf '# demo-fix\n```bash\nnpx -y jscpd@5 .\nnpx knip --fix\n```\n' > "$TD/templates/packs/demo/commands/demo-fix.md"
  # an agent is not scanned for the bare form (only skills and commands carry runnable pre-flights)
  printf '# demo-reviewer\n```bash\nnpx knip --reporter json\n```\n' > "$TD/templates/packs/demo/agents/demo-reviewer.md"
  ( cd "$TD" && git add -A ) || exit 2
  out="$(bash "$SELF" --repo-root="$TD" 2>&1)"; rc=$?
  n="$(printf '%s\n' "$out" | grep -c '^  templates/packs/demo/skills/dup-scan/SKILL.md:')"
  nb="$(printf '%s\n' "$out" | grep -c '^  templates/packs/demo/skills/dup-scan/SKILL.md:[0-9]*  \[npx knip\]')"
  na="$(printf '%s\n' "$out" | grep -c '^  templates/packs/demo/\(agents\|commands\)/')"
  if [ "$rc" -ne 1 ] || [ "$n" -ne 5 ] || [ "$nb" -ne 1 ] || [ "$na" -ne 0 ]; then
    echo "SELF-TEST FAIL — seeded tree: want exit 1 with 5 hits in the skill (1 bare npx; the fix command and the agent exempt), got exit $rc, $n hits, $nb bare, $na outside the skill"; printf '%s\n' "$out"; exit 1
  fi
  # The fixed shape: installed binaries only, NOT-RUN with the install command for the user.
  cat > "$F" <<'EOF'
# dup-scan
```bash
J="$(command -v jscpd || ls node_modules/.bin/jscpd 2>/dev/null)"
[ -n "$J" ] || echo "NOT-RUN (jscpd not installed — to enable: npm i -D jscpd@5)"
npx --no knip --reporter json > "$D/knip.json" || echo "NOT-RUN (knip not installed — to enable: npm i -D knip)"
rg -n 'npx -y|uvx ' .github/workflows
```
Lane: `ruff check --select B .` (absent → NOT-RUN, to enable: `uvx ruff` …) · `docker run --pull=never --rm -i "$HL" hadolint -`
BAD:   RUN npm install   (a Dockerfile line the detector reads)
Never `npx -y` in a pre-flight.
EOF
  ( cd "$TD" && git add -A ) || exit 2
  out="$(bash "$SELF" --repo-root="$TD" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "SELF-TEST FAIL — fixed tree must pass, got exit $rc"; printf '%s\n' "$out"; exit 1
  fi
  echo "self-test: pass (seeded 5 hits incl. bare npx FAIL, fix-command and agent exempt, fixed shape PASS)"
  exit 0
fi

cd "$REPO_ROOT" || exit 2

git ls-files -z --cached --others --exclude-standard 'templates/*.md' 'templates/**/*.md' 'commands/*.md' 'agents/*.md' \
| QUIET="$QUIET" python3 -I -c '
import os, re, sys

# Fix / setup / scaffold artifacts and project-knowledge docs: an install there follows the user'"'"'s word.
SETUP = re.compile(r"""(
    (^|/)CHANGELOG\.md$
  | ^commands/(scaffold-project|upgrade-dep|migrate)\.md$
  | /commands/(dockerize|add-[a-z0-9-]+|setup-[a-z0-9-]+|[a-z0-9-]+-fix|release)\.md$
  | /_examples/(dockerize|add-[a-z0-9-]+|setup-[a-z0-9-]+|[a-z0-9-]+-fix|lighthouse-ci|visual-check|cicd-pipeline)\.md$
  | /references/ | /ai-patterns/ | ^templates/phases/ | ^templates/repo-baseline/ai/ | ^templates/workspace-baseline/
  # skills whose job IS to set a tool up or to run the project under test, not to audit it:
  | /skills/(lighthouse-ci|visual-check|web-vitals-field|lane-[a-z]+|chaos-test|quickstart-verify)/
)""", re.X)

FORMS = re.compile(r"""(
    \bnpx\s+(?:-y|--yes)\b | \bnpx\s+-p\s | \bnpx\s+@?[a-z0-9][\w./-]*@[\w^~.-]+
  | \b(?:pnpm|yarn)\s+dlx\b | \bbunx\b | \bpnpx\b
  | \bnpm\s+(?:i|install|add)\s+(?:-[-\w=]+\s+)*(?:-g\b|--global\b|--prefix\b|@?[a-z0-9][\w./-]*@)
  | \bnpm\s+(?:i|install)\s+(?:-[-\w=]+\s+)*@?[a-z][\w./-]*(?:\s|$|`)
  | \bpip3?\s+install\b | \bpipx\s+(?:run|install)\b | \buvx\b | \buv\s+tool\s+(?:run|install)\b
  | \bgo\s+install\b | \bgo\s+run\s+\S+@\S+ | \bcargo\s+install\b | \bgem\s+install\b | \bbrew\s+install\b
  | \b(?:curl|wget)\b[^|`]*\|\s*(?:sudo\s+)?(?:ba|z)?sh\b
  | \bdocker\s+(?:run|pull)\b
)""", re.X)

LEDGER = re.compile(r"NOT-RUN|NOT-INSTALLED|not[- ]installed|[Tt]o enable|blocked|\b[Nn]ever\b|\bBAD\b|\bGOOD\b|[Tt]o install\b|[Ii]nstall for later")
SEARCH = re.compile(r"^\s*(?:rg|grep|git\s+grep)\s|^\s*\(\x27")
CONTEXT = re.compile(r"\bRUN\s|\brun:\s|\bcommand:\s|\"command\"")
# docker run|pull fetches only a tool image it does not have: a namespaced image (owner/name,
# registry/owner/name) or an image held in a variable ("$HL" hadolint, $DCI docker). A project
# image (`app:test`, `<img>`, `"$IMG"` with options) is the code under test, not a download.
DOCKER_TOOL = re.compile(r"(?<![:/$<\w.-])[a-z0-9][a-z0-9.-]*(?:/[a-z0-9][\w.-]*)+(?:[:@][\w.$@{}:-]+)?(?=[\s\x22\x27`]|$)"
                         r"|\x22?\$\{?[A-Z_]+\}?\x22?\s+(?!-)[a-z][\w-]*")

# A bare `npx <tool>` (no --no / --no-install, no -y, no @version): installs the tool in a non-TTY
# shell when it is absent. Read only in skills and commands (the runnable pre-flights).
BARE_NPX = re.compile(r"\bnpx\s+(?!-)@?[a-z][\w./-]*(?![\w./-]*@)")
PREFLIGHT = re.compile(r"(^|/)(skills|commands)/")

def hits_in(text, bare=False):
    if bare:
        for m in BARE_NPX.finditer(text):
            yield m.start(), m.group(0)
    for m in FORMS.finditer(text):
        s = m.group(0)
        if s.startswith("docker"):
            rest = text[m.end():]
            if "--pull=never" in rest or not DOCKER_TOOL.search(rest):
                continue
        yield m.start(), s

bad = []
for path in sys.stdin.read().split("\0"):
    if not path or SETUP.search(path):
        continue
    try:
        lines = open(path, encoding="utf-8").read().split("\n")
    except OSError:
        continue
    fence, header = None, []
    bare = bool(PREFLIGHT.search(path))
    for n, line in enumerate(lines, 1):
        st = line.lstrip()
        if st.startswith("```") or st.startswith("~~~"):
            if fence is None:
                lang = st[3:].strip().split(" ")[0].lower()
                fence = lang or "text"
            else:
                fence = None
            continue
        table = fence is None and st.startswith("|")
        if table and re.match(r"^\|[\s:|-]+\|?\s*$", st):
            continue
        if fence is None and not table:
            header = []
        if fence is not None:
            if fence in ("dockerfile", "docker", "yaml", "yml", "json", "jsonc", "toml", "hcl", "diff", "regex"):
                continue
            if st.startswith("#"):
                ticks = [(m.start(1), m.group(1)) for m in re.finditer(r"`([^`]+)`", line)]
                spans = ticks or [(len(line) - len(st) + 1, st[1:])]
                prose = True
            else:
                spans, prose = [(0, line)], False
        else:
            prose = True
            spans = [(m.start(1), m.group(1)) for m in re.finditer(r"`([^`]+)`", line)]
        if table and not header:
            header = [c.strip().lower() for c in st.strip("|").split("|")]
            continue
        if not spans or SEARCH.search(line):
            continue
        for off, span in spans:
            for pos, s in hits_in(span, bare):
                at = off + pos
                if LEDGER.search(line[:at]) or CONTEXT.search(span[:pos]):
                    continue
                if at and line[at - 1] in "\x22\x27" and line[at - 2:at - 1] != "=":
                    continue   # quoted text: an echo, an output line, a config value the detector quotes
                if table:
                    col = line[:at].count("|") - 1
                    if 0 <= col < len(header) and re.search(r"install|enable", header[col]):
                        continue
                if fence is not None and not prose and line[:at].count("\x27") % 2:
                    continue   # inside single quotes: an echo or a pattern, never run
                if prose and len(span) - pos < 20:
                    continue   # a form NAMED in prose (`npx -y`, `docker run --init`), not a command
                bad.append((path, n, s.strip(), line.strip()[:150]))
quiet = os.environ.get("QUIET") == "1"
if bad:
    print("FAIL — %d install/download form(s) an audit would RUN (use the installed tool; absent → "
          "NOT-RUN (<tool> not installed — to enable: <cmd>) and the grep lane):" % len(bad))
    for p, n, s, l in bad:
        print("  %s:%d  [%s]  %s" % (p, n, s, l))
    sys.exit(1)
if not quiet:
    print("no-install-in-preflight: 0 hits")
'

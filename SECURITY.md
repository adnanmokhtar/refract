# Security Policy

Refract installs itself into your `$HOME`, ships hooks that execute on every agent tool call, and
puts a directory of shell scripts on a path your AI assistant can invoke. That is a real surface,
and this document describes it plainly rather than reassuringly.

---

## Supported versions

There are no release tags. `main` is the only supported version, and the Claude Code install is a
**symlink** into your clone — so whatever `main` contains is what runs on your machine, immediately
after `git pull`, with no install step in between.

| Version | Supported |
|---|---|
| `main` (latest commit) | Yes |
| Any older commit you have checked out | No — pull first, then re-verify |

Versioning inside the repo (`_version.json` in every pack and adapter) tracks *content* drift for
`/setup-project`'s upgrade path. It is not a security-release channel.

---

## Reporting a vulnerability

**Do not open a public issue, pull request, or discussion for a security problem.**

Two private routes, either is fine — use both if it is urgent:

1. **GitHub Security Advisories** — <https://github.com/adnanmokhtar/refract/security/advisories/new>
   (preferred: keeps the report, the fix, and the disclosure in one place)
2. **Email** — **iconxweb@gmail.com**, subject line starting `SECURITY:`

Please include: the file and line, what an attacker (or a misbehaving agent) achieves, the exact
command or payload that demonstrates it, and your environment (OS, shell, bash version, which AI
tools are installed). A failing fixture under `tests/hooks/cases/` or `tests/validators/` is the
single most useful thing you can attach — it becomes the regression test.

### What to expect

This is a single-maintainer project. These are honest targets, not an SLA:

| Stage | Target |
|---|---|
| Acknowledgement that the report was received | 3 business days |
| Initial assessment — confirmed / not-a-vuln / need more info | 7 days |
| Fix or documented mitigation for a confirmed high-severity issue | 30 days |
| Fix for lower-severity issues | Next substantive change to that area |

Disclosure is coordinated: the advisory goes public with the fix, and you are credited unless you
ask otherwise. There is no bug bounty.

---

## The security model of the tool itself

Three things here run code or write outside the repository. Each is described with what it does,
what stops it going wrong, and where the mitigation ends.

### 1. It writes into `$HOME`

`scripts/sync-to-global.sh` detects installed AI tools and writes to their global config
directories:

| Tool | Path | Form |
|---|---|---|
| Claude Code | `~/.claude/{commands,templates,scripts}/` | **Symlinks** back into your clone |
| Kimi Code | `~/.kimi/skills/<cmd>/SKILL.md` | Generated copy |
| Qwen Code | `~/.qwen/commands/*.md` | Generated copy |
| Gemini CLI | `~/.gemini/commands/<cmd>.toml` | Generated copy |
| OpenCode | `~/.config/opencode/commands/<cmd>.md` | Generated copy |
| Codex CLI | `~/.agents/skills/<cmd>/SKILL.md` | Generated copy |

**The sharp edge is the symlinks.** Because `~/.claude/commands`, `~/.claude/templates` and
`~/.claude/scripts` point into your working copy, a `git pull` — or a merged pull request, or a
branch you checked out to review — changes what your agent executes on its very next turn. There is
no build, no install, no confirmation. Treat pulling this repo the way you would treat installing a
shell plugin: read the diff, or pin to a commit you have reviewed.

**Mitigations:**

- **Dry run is the default.** `sync-to-global.sh` with no flags writes nothing; it prints the plan
  and exits. Writes require an explicit `--apply`.
- **It refuses to clobber.** If a destination is a real file, or a symlink pointing somewhere else,
  it reports drift and exits 1. Overwriting needs an explicit `--force`.
- **It only removes what it owns.** `--unlink` deletes a Claude Code entry only when the symlink
  target matches this repo, and a generated copy only when it carries the marker string
  `source: refract/commands/` (or the pre-rename `source: claude-config/commands/`, still
  recognised so older installs stay uninstallable). Files you put there yourself are left alone.
  `./scripts/sync-to-global.sh --unlink --apply` is a complete uninstall.
- **Your settings are never touched.** `~/.claude/settings.json` and `settings.local.json` are not
  read, written, or backed up by any script in this repo.
- **Drift is detectable.** `./scripts/verify-sync.sh` exits non-zero and names any entry that is
  missing, is a real file instead of a symlink, or points outside this repo.

**Where it ends:** nothing verifies the *content* of what you pulled. The scripts protect the
install's shape, not its trustworthiness.

### 2. It ships hooks that execute

`/setup-project` installs 13 hook scripts into a target repository's `.claude/hooks/` and wires them
into that repo's `.claude/settings.json` across `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`
and `Notification`. From then on they run — with your user's privileges — on every matching agent
tool call in that project.

Three of them are security gates that can **block** a tool call (exit 2):

| Hook | Blocks |
|---|---|
| `guard-destructive.sh` (PreToolUse: Bash) | Push to a protected branch; force push (`--force-with-lease` is allowed); `rm -rf` on `/`, `~`, `$HOME`, an unresolved `$VAR`, `../..`, or a system directory; `DROP TABLE/DATABASE/SCHEMA`; `DELETE FROM` with no `WHERE`; `TRUNCATE TABLE`; `chmod 777` / `a+rwx`; `curl … \| sh`; redirection into a raw device; `mkfs` / `dd if=/dev/…`; `git reset --hard`; `git clean -f`; `git branch -D`; fork bombs; package publishing (`npm`/`yarn`/`pnpm`/`bun publish`, `cargo publish`, `gem push`, `twine upload` — `--dry-run` allowed). Detects patterns inside chained commands (`&&`, `;`, `\|`). |
| `pre-edit-guard.sh` (PreToolUse: Edit/Write/MultiEdit) | Writes to `.env*`, `*.pem`, `*.key`, `*.crt`, `*.p12`, `id_rsa`, `credentials.json`, `.npmrc`, `.pypirc`, secrets directories, lockfiles, generated and minified files, `node_modules/`, binaries — **and the hook files themselves**, so an agent cannot disable its own guardrails by editing them. |
| `secret-scan.sh` (PreToolUse: Edit/Write/MultiEdit) | Writes introducing a credential shape: `sk-ant-…`, `sk-…`, `AKIA…`/`ASIA…`, `AIza…`, `gh[pousr]_…`, `github_pat_…`, `xox[baprs]-…`, Twilio SIDs, `-----BEGIN … PRIVATE KEY-----`, JWTs, and connection strings with embedded `user:pass@host`. |

The other ten (`post-edit-check`, `format-on-save`, `auto-test`, `session-start`,
`update-session-log`, `verify-gate`, `notify`, `post-commit-learn`, `post-merge-learn`,
`inject-path-rules`) are workflow hooks. `inject-path-rules.sh` is context-only and always exits 0.

**Mitigations:**

- **Every gate is pinned by fixtures, and the fixtures run in CI.** `tests/hooks/run.sh` replays 40
  cases — 17 for `guard-destructive`, 11 for `pre-edit-guard`, 7 for `secret-scan`, 5 for
  `inject-path-rules` — on every push and pull request. The filename encodes the required exit code,
  so a hook silently regressing to always-allow is a red build, not a field incident. If you report
  a bypass, the fix ships with a new fixture.
- **The hooks are plain, readable bash** and they land in *your* repository under version control.
  You can read them, diff them, and delete them.
- **Opt-outs are explicit and local**: `touch .claude/.no-guard-destructive`,
  `.claude/.no-pre-edit-guard`, `.claude/.no-secret-scan`, `.claude/.no-path-rules`. Protected
  branches are configurable via `CLAUDE_PROTECTED_BRANCHES`.

**Where it ends — read this part:**

- These hooks are **heuristics against agent mistakes, not a sandbox, and not a defense against a
  determined adversary.** `guard-destructive.sh` pattern-matches a command string. Indirection
  defeats it: a destructive command inside a script file, behind `eval`, base64-decoded, or built
  from variables will not match.
- `secret-scan.sh` matches known key *shapes* only. A bespoke or internal credential format passes
  through. It also deliberately skips `*.example`, `*.sample`, `*.dist`, `*.md`, `*.lock` and test
  paths to keep false positives near zero — which means **a secret written into a markdown file is
  not blocked**. That is a documented trade-off, not an oversight.
- A blocked hook stops one tool call. It cannot undo one that already ran, and it cannot constrain
  anything the agent does through a channel the matcher does not cover.
- `guard-destructive.sh` and `secret-scan.sh` prefer `jq` and fall back to `sed` when it is absent;
  the fallback extracts less reliably from unusual payloads.

### 3. `scripts/*.sh` run on your machine

Everything in `scripts/` is symlinked into `~/.claude/scripts` — so your AI assistant can invoke
any of it directly. Most are read-only validators and linters. The ones that write are the `sync-*`,
`apply-*`, `migrate-*` and `seed-*` families, and they write into the repository you point them at.

**Mitigations:**

- CI runs the full validator suite on every push, so a script that starts doing something new fails
  a fixture before it reaches a user — provided the behaviour is covered by one.
- Validators accept `--repo-root=<dir>` and are exercised against self-contained fixture repos under
  `tests/validators/`, not against your real tree.

**Where it ends:** they are shell scripts running as you. There is no privilege separation, no
sandbox, and no confirmation prompt beyond the ones individual scripts implement.

---

## Scope

**In scope:**

- Anything in this repo that writes outside the repository it was pointed at — path traversal,
  unquoted expansion, a `--unlink` that removes a file it does not own, a sync that escapes `$HOME`.
- A bypass of `guard-destructive.sh`, `pre-edit-guard.sh` or `secret-scan.sh` that a *reasonable*
  agent command would hit — i.e. one that does not depend on deliberate obfuscation.
- Command injection through a filename, branch name, argument, or hook payload.
- Secrets, tokens, or personal paths committed to this repository.
- An adapter that emits content into a target repo which executes in a way the contract does not
  document.
- A CI gate that can be made to pass while its contract is violated.

**Out of scope:**

- Vulnerabilities in Claude Code, Cursor, Gemini CLI, OpenCode, Kimi, Qwen, Codex, or any other
  host tool. Report those to the vendor.
- "An AI agent can write insecure code." True, and not a vulnerability in this repo.
- Obfuscated bypasses of the hooks (see the limits above). Still worth reporting — several became
  fixtures — but they are hardening, not vulnerabilities.
- Anything requiring an attacker to already have shell access as your user, or write access to your
  clone. At that point the symlinks are the least of the problem.
- Findings from an automated scanner with no demonstrated impact.

---

## Hardening checklist for users

- Clone to a stable path you control. Do **not** clone to `~/.claude/` itself.
- Run `./scripts/sync-to-global.sh` (dry run) and read the plan before `--apply`.
- Run `./scripts/verify-sync.sh` after any pull; investigate drift rather than `--force`-ing past it.
- Review the diff before pulling. The symlink install means there is no second chance to.
- Keep the three security hooks enabled. If you must disable one, disable it per project with the
  flag file and write down why.
- Removing everything: `./scripts/sync-to-global.sh --unlink --apply`. To undo a project scaffold,
  delete that project's `.claude/`, `ai/` and `CLAUDE.md` — nothing else is touched.

---

Refract is MIT-licensed and provided without warranty. See [LICENSE](LICENSE).

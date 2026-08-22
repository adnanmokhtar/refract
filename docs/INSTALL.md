# Installing Refract

Three routes. They are not alternatives so much as layers: the plugin gets the commands in front of
you in ten seconds, the sync makes them real across every tool, and `/setup-project` makes them
specific to one repository.

| Route | One line | Gives you | Does **not** give you |
|---|---|---|---|
| 1 · Plugin | `/plugin install refract@refract` | 15 commands inside Claude Code, namespaced `/refract:…` | Any other tool; the framework file tree at the paths the commands read |
| 2 · Sync | `./scripts/sync-to-global.sh --apply` | The same 15 commands un-namespaced, in Claude Code **and** Gemini CLI, OpenCode, Kimi, Qwen, Codex — plus `templates/` and `scripts/` under `~/.claude/` | Anything inside a specific repository |
| 3 · Project | `/setup-project` | Packs, agents, rules, hooks and per-project adapters written into one repository | A global surface — it assumes route 2 already ran |

---

## Route 1 — Claude Code plugin

```
/plugin marketplace add adnanmokhtar/refract
/plugin install refract@refract
```

Or from a shell, without opening a session:

```bash
claude plugin marketplace add adnanmokhtar/refract
claude plugin install refract@refract
```

Both names are `refract` — the first is the marketplace, the second the plugin inside it, which is
why the install argument reads `refract@refract` (`plugin@marketplace`).

**What it does.** Registers the marketplace, copies this repository into Claude Code's plugin cache
and exposes `commands/` as namespaced skills — one per file, **15 today**. The cache is your working
tree minus `.git`, so its size follows whatever untracked scratch the clone happens to hold — `du`
reported 20 MB in the run below, about 3 MB of that a local build cache.

Two different things were checked, and they are not the same strength of evidence:

- **The cache contents are verified.** Running the add/install pair against an isolated
  `CLAUDE_CONFIG_DIR` on Claude Code 2.1.224 produces a cache whose top-level `commands/` holds all
  fifteen files, `delegate.md` included, and no `.git`.
- **The picker was checked when there were fourteen.** All fourteen loaded as `/refract:do`,
  `/refract:setup-project`, `/refract:audit`, `/refract:optimize`, `/refract:align`,
  `/refract:refactor`, `/refract:polish`, `/refract:unify-surfaces`, `/refract:roadmap`,
  `/refract:scaffold-project`, `/refract:refine-prompt`, `/refract:task`,
  `/refract:setup-project-adapters`, `/refract:setup-project-health`. `/delegate` shipped after that
  session and **has not been observed in the picker** — it is in the cache, which is a strong
  expectation that `/refract:delegate` resolves, not an observation that it does. Confirm it
  interactively before relying on it.

**What it does not do.**

- **Claude Code only.** Cursor, Windsurf, Gemini CLI, OpenCode, Kimi, Qwen, Codex, Cline, Continue,
  Copilot and Aider see nothing. Cross-tool distribution is route 2, and it is the whole point of
  the project.
- **The names stay namespaced.** You type `/refract:audit`, not `/audit`. That is Claude Code's
  plugin contract, not a choice made here.
- **It does not install the framework tree where the commands look for it.** Fourteen of the
  fifteen commands cite `templates/…`, `~/.claude/templates/…` or `~/.claude/scripts/…` by path;
  `/refine-prompt` is the only one that cites none. `/setup-project` names a `templates/` path 42
  times, `/refactor` 25, `/setup-project-adapters` 16.
  A plugin install creates none of those paths. The copy in the plugin cache does contain the full
  tree, but the commands do not address it that way today.

  In practice: `/refract:refine-prompt` is fully self-contained and `/refract:do` nearly so, but the
  phase-driven commands — `/refract:setup-project` above all — will not find their phase files and
  will halt or degrade. This has not been benchmarked run-by-run; the dependency counts above are
  measured from the command sources, the runtime behaviour is inferred from them. Treat route 1 as
  a way to read the commands and try the light ones, and route 2 as the install.
- **It is not a zero-write install.** Claude Code adds `extraKnownMarketplaces` and `enabledPlugins`
  keys to `~/.claude/settings.json` and populates `~/.claude/plugins/`. Nothing else in your
  settings is touched. (Verified by running the add/install pair against an isolated
  `CLAUDE_CONFIG_DIR`.)

**Updating.** `/plugin marketplace update refract`, then `/plugin update refract@refract` — a
restart applies it. The plugin is pinned to the `version` in the manifest, so you receive changes
when that field is bumped, not on every upstream commit.

**Removing.** `/plugin uninstall refract@refract` then `/plugin marketplace remove refract`.

---

## Route 2 — clone and sync (the full install)

```bash
# 1. Clone somewhere stable — NOT at ~/.claude/
git clone https://github.com/adnanmokhtar/refract.git ~/Workspace/Projects/refract
cd ~/Workspace/Projects/refract

# 2. Preview. Dry run is the default; it writes nothing.
./scripts/sync-to-global.sh

# 3. Apply
./scripts/sync-to-global.sh --apply

# 4. Confirm
./scripts/verify-sync.sh
```

Needs `bash` and `git`; the validators and the cheatsheet generator also use `python3`.

**What it does.** Detects every installed AI coding tool and writes the 15 global commands into each
one's native global surface — symlinks for Claude Code (`~/.claude/commands`, `~/.claude/templates`,
`~/.claude/scripts`), generated copies for Gemini CLI (`.toml`), OpenCode, Kimi (`SKILL.md`), Qwen
and Codex. Because Claude Code is symlinked, editing a file in the clone takes effect immediately
with no re-sync; the copy-based tools need another `--apply`.

Crucially, this is the route that puts `templates/` and `scripts/` at `~/.claude/`, which is where
the commands expect to find the governance files, phase files and helper scripts they cite.

**What it does not do.**

- **It configures no repository.** No pack, agent, rule or hook lands in a project until you run
  route 3.
- **Six tools get nothing globally**: Cursor, Windsurf, Cline, Continue, Copilot and Aider have no
  global command primitive. They are wired per project, at route 3, by
  `/setup-project-adapters`.
- **It does not touch `~/.claude/settings.json` or `settings.local.json`.** Those stay yours.

`--force` replaces stale real files, `--unlink` removes everything Refract owns and nothing else.

**If you also ran route 1**, you will have two surfaces over the same commands: `/audit` from the
live symlinked clone and `/refract:audit` from the version-pinned plugin cache. That works, but they
can drift apart. Pick one, and uninstall the other.

---

## Route 3 — per repository

Run inside the project you want configured:

```
/setup-project
/setup-project "Multi-tenant SaaS: API + admin + storefront, Stripe, multi-tenant"
```

**What it does.** Detects whether the folder is empty or a decade-old codebase, refines the prompt,
mixes packs from the tracks it detects, and writes `CLAUDE.md`, `.claude/` and `ai/` into the
repository — including the pack commands for the selected tracks and the per-project adapter files
(`.cursor/commands/`, `.windsurf/workflows/`, `.clinerules/workflows/`, `.continue/prompts/`,
`.github/prompts/`, `CONVENTIONS.md`). It shows a plan and waits for approval before executing.

Three modes, deliberately not redundant: `--enhance` adds missing files only, `--refresh` backs up
and regenerates from current templates, `--refine` deepens existing artifacts against the real code.

Companion commands: `/setup-project-health` for a read-only drift and staleness report,
`/setup-project-adapters` to re-sync tool adapters after you install a new tool.

**What it does not do.**

- **It does not modify your source code.** It writes configuration and knowledge artifacts.
- **It does not auto-upgrade.** Pulling a newer Refract never changes how an already-configured
  repository behaves; you opt in with `/setup-project --enhance`.
- **It is not a substitute for route 2.** The command reads its phase files from the framework tree.

**Undoing it**: delete `.claude/`, `ai/` and `CLAUDE.md` from the project. Everything else is yours.

---

## Which one

- Want to look at it → route 1.
- Want to use it → route 2, then route 3 in each repository.
- Use more than one AI tool → route 2 is the only route that reaches them.
- On a machine where you cannot clone → route 1, and expect the phase-driven commands to be limited.

Troubleshooting for the sync route lives in the [README](../README.md#troubleshooting). The command
manual is [docs/COMMANDS.md](COMMANDS.md); failure modes and pitfalls are in
[docs/REFERENCE.md](REFERENCE.md).

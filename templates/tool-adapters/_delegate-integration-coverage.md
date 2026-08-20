# `/delegate` integration — per-tool adapter coverage

Cross-cuts the tool-adapter registry. Documents how each tool surfaces the **cross-tool dispatch command `/delegate`** (`commands/delegate.md`) — and, as a separate question with a different answer, whether that tool's own CLI can be dispatched *to*.

`/delegate` is the second **integration command** and the first **CLI-backed** one (see `_registry.md` § Top-level orchestration commands → *Cross-tool dispatch*). `/task` crosses to a task tracker and writes status back; `/delegate` crosses to another CLI and brings a diff back. It is the only command in this repo that **uses** an AI coding tool rather than configuring one — the adapter tree is the write path, this is the read-back.

The lifecycle is single-task and tool-agnostic: **resolve implementer → git preflight → compose brief → dispatch one bounded run → capture diff + `result.json` → the human re-runs the gates and commits**. None of it is Claude-specific, and none of it is stack-specific. What varies per tool is not the lifecycle — it is whether the tool can run the relay at all, and whether its own binary is installed to receive work.

> **Canonical sources**: `commands/delegate.md` (judgement half — what is worth delegating, the brief contract, the tri-state, the HALT list) + `scripts/delegate-relay.sh` (mechanical half — preflight, launch, watchdog, diff capture, contract `delegate-relay.result.v1`) + `templates/snippets/plan-flag.md` (the `--plan` seam; the brief *is* the plan artifact). There is **no** `templates/integrations/*` analogue and none is needed — implementer profiles live in `impl_profile()` / `impl_argv()` inside the relay, not in a template.

## The two roles a tool can play

There is no lifecycle substitution here. `/task` replaces exactly one step per adapter (`/do` → the tool's own dispatch); `/delegate` replaces none, because the relay is stack- and tool-agnostic bash. What varies is which of two **independent** roles a tool can fill:

| Role | What it requires | Where the answer comes from |
|---|---|---|
| **Dispatcher** (host — runs `/delegate`) | (a) arbitrary shell from inside a workflow, (b) file reads, (c) a **bounded blocking subprocess** (30m watchdog by default). (a) decides host-or-not — (b) never discriminates, every adapter has it. **full vs partial is not one test**: a host is *partial* when something between the primitive and the 30m block is known-unreliable, and each partial row below names its own reason (Codex: the block is human-attended, not unattended · Kimi: the invocation surface is not guaranteed to execute what it loads · Windsurf: IDE-bound, so no unattended or CI host). Do not read `partial` as a single graded score. | This repo's own record: the "✅ Executes" column of `_registry.md` § *Command translation*, plus each `adapter.md`'s recorded tool surface. |
| **Implementer** (target — receives the brief) | A **headless binary on PATH**, plus a live auth session for that vendor. | `command -v` at runtime, over the 10 names in `KNOWN_IMPLEMENTERS` (`scripts/delegate-relay.sh`). **Not** this matrix and not the adapter tree. |

A tool can be one, both, or neither. Requirement (a) also rules out a whole class of near-misses: a fixed post-edit hook slot is not "shell from inside a workflow" — it fires *after an edit*, so it cannot launch a relay run, block on it, and read `result.json` back.

**Being configured by this repo, being installed, and being dispatchable are three different facts.** `commands/delegate.md` states it once ("a configured adapter is not an installed CLI"); this is the adapter tree saying it back. 12 adapters are configured here; 10 names can be implementers; `cursor-agent` is a binary **no adapter installs or configures** — the Cursor adapter's target files are the IDE's `.cursor/**`, and the CLI only shows up as a dispatch target; `continue` and `windsurf` have adapters and no CLI at all.

**Prerequisite, per role.** Dispatcher: `scripts/delegate-relay.sh` installed into `~/.claude/scripts/` alongside the other companion scripts. Implementer: the binary on PATH **and authenticated**. Gate G2 proves only that `<cli> --version` (for `copilot`, `copilot version`) succeeds — it does not and cannot prove a live session. An unauthenticated CLI exits non-zero, usually fast, and `commands/delegate.md` requires its own error text be surfaced verbatim rather than re-worded into a guess; on macOS a sandboxed parent can block Keychain access and make an authenticated CLI report otherwise.

## Capability mapping per tool

Roles as this repo records them **today**. `host` = can run the relay and read the result back; `impl` = its binary is one of the 10 in `KNOWN_IMPLEMENTERS`. No classification here is upgraded past what a file in this repo actually says.

| Tool | Roles | Dispatcher primitive | Implementer binary | Notes |
|---|---|---|---|---|
| Claude Code | **host (full) · impl** | `.claude/commands/delegate.md` (native) | `claude` (brief on stdin) | Source of truth — `/delegate` ships here. Read-only via `--permission-mode plan`; resume via `--resume`. Dispatching to `claude` from Claude Code is the **self-dispatch no-op** — pick a different implementer. |
| Cursor | **host (full) · impl** | `.cursor/skills/delegate/SKILL.md` (skills-first — **not** `.cursor/commands/`) | `cursor-agent` — the CLI, **not** the IDE | `_registry.md` calls Cursor "IDE-bound": true of the *editor*, stale for the *CLI*. A `beforeShellExecution` hook with `failClosed: true` can deny the relay launch — document that, don't fight it. Read-only via `--plan`. |
| Copilot | **host (full) · impl** | `.github/prompts/delegate.prompt.md` (**`mode: agent` REQUIRED**) | `copilot` | `mode: edit` edits files but runs no shell — a delegate prompt written that way silently cannot launch the relay. Version probe is `copilot version`, not `--version`. Read-only via `--mode plan`; resume via `--resume`. |
| Gemini CLI | **host (full) · impl** | `.gemini/commands/delegate.toml` (**TOML only**) | `gemini` | Two shell paths, one usable: `!{}` injection prompts for confirmation, so the relay launches through the agent's own `run_shell_command` tool. No per-command tool whitelist, so read-only *intent* on the dispatcher side is self-gated prose only. Read-only via `--approval-mode plan`; resume via `--resume`. |
| Qwen | **host (full) · impl** | `.qwen/commands/delegate.md` (Markdown) | `qwen` | A subagent form MUST list `run_shell_command` in `tools:` — a delegate subagent authored read-only cannot run the relay. As implementer, `--approval-mode plan` is marked *unverified* in `commands/delegate.md` while the relay profiles it `native`; the runtime `--help` probe decides and refuses on drift (`enforcement: unverified`, exit 5). Resume unverified → `--session` refused. |
| OpenCode | **host (full) · impl** | `.opencode/commands/delegate.md` (**`agent: build` REQUIRED** — plan mode has read tools without write/shell) | `opencode` — **`--model` required** | `opencode_classify_command_agent` classifies deterministically, so `/delegate` must be added to that mapping or it defaults to the wrong agent. A bare `--to=opencode` hard-fails: `P_NEEDS_MODEL=1` makes `--model=` a **precondition**, not a parenthetical. Read-only via `--agent plan`. Resume unverified → `--session` refused. |
| Codex | **host (partial) · impl** | `.agents/skills/delegate/SKILL.md` (Open Agent Skills; no user-extensible slash — `/skills` or `$delegate`) | `codex` | Codex has a Bash tool and can *launch* the relay, but `codex/adapter.md` also records "no headless mode for fully autonomous loops — the user must press through approval prompts", which turns the 30m block into a human-attended wait. **That line is contradicted in its own file** (the line above it spawns per-row workers via `codex exec`) and by `_registry.md`'s verified `codex exec`. Until it is resolved: partial. As implementer, read-only via `--sandbox read-only`; resume via `codex exec resume <id>`. |
| Kimi | **host (partial) · impl** | `.kimi/skills/delegate/SKILL.md` + `.kimi/subagents/delegate.yaml` — the subagent `tools:` whitelist **must include `shell`**, and the subagent must be registered in a parent agent YAML or it never dispatches | `kimi` | Shell is not the problem; *invocation* is. A regular `/skill:<name>` injects the body as "contextual guidance, not strict system prompt override", so the EXECUTE NOW preamble is required and the OPTIONAL Flow-Skill upgrade is what makes execution explicit. Kimi is the one implementer where **`--read-only` is `unenforceable`** — it documents no read-only mode (`P_RO_CLASS="none"`); the relay refuses at exit 5 unless `--accept-unenforced`. Resume unverified → `--session` refused. |
| Windsurf | **host (partial) · NOT an implementer** | `.windsurf/workflows/delegate.md` (manual-invoke) | **none — no headless CLI** | Cascade never auto-invokes workflows, which is a **fit**, not a defect: `/delegate` is user-dispatched by definition and must never auto-fire. IDE-bound, so it cannot host a relay run from CI. Absent from `KNOWN_IMPLEMENTERS` — not a gap to close, just not a CLI. |
| Cline | host **UNKNOWN** · **impl** | `.cline/skills/delegate/SKILL.md` (Skills must be enabled in Settings → Features) — **conditional on Cline being able to run shell** | `cline` (brief on **stdin**) | **Stated as unknown, not assumed.** No line in `cline/adapter.md` names a command-execution tool; the one convention it does record (shell steps in skills — "user runs manually") points the other way, and its PreToolUse example blocks a `.env` *write*, not a shell call. **What would settle it:** a line naming Cline's command-execution tool, or its PreToolUse matcher token, the way `codex/adapter.md` names `Bash\|apply_patch` and `qwen/adapter.md` names `^bash$`. Until then Cline is on the record as an implementer only. Read-only via `--plan` + `--auto-approve false`; resume unverified → `--session` refused. |
| Aider | **NOT a host · impl** | `CONVENTIONS.md § User-invoked procedures` with an EXECUTE-NOW preamble — **no executable primitive**; the *human* runs `delegate-relay.sh` in a terminal | `aider` | Aider's only shell is two fixed post-edit slots (`lint-cmd` / `test-cmd`) that fire *after an edit* — they cannot launch a bounded run and read `result.json` back. That preamble is honest coverage, not hosting. **Aider commits by default**: `--auto-commits` and `--dirty-commits` are both on upstream and the second commits *your* pre-existing work; the relay pins both off and exposes no way to re-enable them. This is the one implementer where invariant 2 needs a flag, not just a brief clause. Read-only via `--dry-run`; resume unverified → `--session` refused. |
| Continue.dev | **neither** | **cannot dispatch** — `continue/adapter.md` records that Continue does not execute shell from a prompt, and it has no lifecycle-hook mechanism | **none — no headless CLI** | The honest entry is a NOT-SUPPORTED note, not a workaround. The one thing Continue still does is what any editor does: open `delegate.diff` and `result.json` as files for the human review step (G7) — do not dress that up as coverage. **Tension to re-verify:** `_registry.md` says Continue prompts need Agent mode "for autonomous tool execution", which is about *edits*, not shell; if Agent mode ships a run-command tool, the `adapter.md` line is stale. **What would settle it:** the current `config.yaml` reference / Agent-mode tool list showing a run-command tool. |

**Roles at a glance** — both: Claude Code, Cursor, Copilot, Gemini, Qwen, OpenCode, Codex, Kimi (8). Host-only: Windsurf. Implementer-only *on this repo's record*: Aider, Cline. Neither: Continue.

**Rule of thumb — there isn't one.** `/task`'s rule ("any tool with MCP support gets the full command") has no counterpart here. Two independent questions, two different answers per tool, and the asymmetry is this doc's whole reason to exist.

## Flags (every adapter's `/delegate` MUST expose these)

| Flag | Effect |
|---|---|
| `--to=<cli>` | Implementer to dispatch to. Omitted → detect what is installed; more than one candidate → ask **one** question. Never silently picks. |
| `--read-only` | Diagnosis / review run: request the implementer's native read-only or plan mode. Refused (exit 5) when that CLI has none. |
| `--gate=<cmd>` | A real command the implementer must run and **you** will re-run. Repeatable. Copied from the project's own config, never invented. |
| `--model=<id>` | Pin the implementer's model. **Required for `opencode`** (`P_NEEDS_MODEL=1` — the relay refuses to launch without it, exit 2); optional everywhere else. |
| `--session=<id>` | Resume a prior run of the same CLI with a **delta** brief. Refused where the relay has not verified that CLI's resume shape. |
| `--files=<globs>` | Declare in-scope paths in the brief. Scoping and review aid — **not** a permission boundary. |
| `--allow-dirty` | Proceed with a dirty tree; the pre-existing dirt is fingerprinted first so touched-files stays a true delta. Default is halt-on-dirty. |
| `--timeout=<dur>` | Watchdog, default 30m. On expiry the process tree is killed and a partial result is still written. |
| `--dry-run` | Print resolved implementer, argv, brief and git baseline; launch nothing. |
| `--plan` | Universal handoff flag — write the brief to `.claude/plans/` and exit before dispatch. |

Translators MUST carry all ten — they are the command surface, not Claude-only behaviour. Dropping `--model=` in particular is not a cosmetic trim: it silently removes `opencode` from the reachable implementer set, because the relay refuses to launch that one without it.

**The two "emit, don't run" escape hatches are not interchangeable**, and the difference is exactly the thing a tool with an uncertain shell surface cares about. `--plan` is handled **agent-side** — it composes the brief, writes it to `.claude/plans/`, and exits **without invoking the relay at all**. It needs a file write and nothing else, so it is the safe first invocation even in a tool whose shell surface is unproven (Cline). It is **not** a back door into hosting: authoring a brief is not dispatching one, and a tool that can only do `--plan` (Continue) is still not a dispatcher — it has produced a document for a human to run elsewhere. `--dry-run` is a **relay** flag: it prints the resolved implementer, argv, brief and git baseline and launches nothing, but reaching it still requires running `delegate-relay.sh`, which requires a shell. In a tool whose shell surface is unproven, `--plan` is the probe and `--dry-run` is not.

**The relay's flag vocabulary is not identical to this table's.** `--to=` is the *command* surface; the relay's equivalent is **`--implementer=`** and it rejects `--to=` outright (`unknown arg`, exit `2`). `--plan` is command-only and never reaches the relay. Everything else here (`--read-only`, `--gate=`, `--model=`, `--session=`, `--files=`, `--allow-dirty`, `--timeout=`, `--dry-run`) passes through under the same name. **A translation that shells out to the relay MUST do that rename** — miss it and the run dies at argument parsing, before any preflight, with nothing dispatched and no `result.json` to read.

The relay also exposes flags the command surface does not have to re-expose but adapters should know exist: **`--accept-unenforced`** (allow a `--read-only` run whose enforcement is `unverified` / `unenforceable`), **`--out=`** (artifact dir), **`--repo=`**, **`--brief=`** (brief from a file rather than stdin), **`--no-commit-shim`**, **`--quiet`**, and **`--list`** (print implementer availability; the one flag that runs no preflight at all and is therefore safe anywhere).

## Run artifacts (what an adapter points users at)

`.claude/delegate/<ts>-<impl>/` inside the target repo, unless `--out=` moves it: `brief.md` (the composed brief), `stdout.log` / `stderr.log`, `delegate.diff`, `result.json` (`delegate-relay.result.v1`), `shim-denials.log`. Plus one audit line appended to `ai/_history.md`.

Two things follow for adapters. The relay filters its own output dir out of `touchedFiles` and out of the captured diff — it never reports its own artifacts as the implementer's work — and the run notes suggest gitignoring the directory. And **`.claude/delegate/**` does not belong in any validator hook glob**: it is a third-party process's captured output, not this repo's artifact tree. There is no `validate-delegate-artifacts.sh` and no `ai/delegate/` tree to validate.

## Resilience: no fallback exists — say so plainly

`/task` degrades from MCP to REST because both channels reach the same provider, which is why Aider's "degraded path" there is not a special case. **`/delegate` has no second channel.** No implementer on PATH means nothing was delegated: there is no API mode, no gateway, no in-session substitute. Invariant 1 is that a separate CLI edits a real working tree and the diff is the deliverable — a fallback that skipped the separate process would not be a degraded `/delegate`, it would be a different command wearing its name.

Do not invent one in a translation. An adapter that "falls back" to implementing the task itself has silently converted a delegation request into `/do`.

## Degradation when no implementer is installed

- **Zero candidates** → halt, relay exit `3`. List what `--list` looked for. Never fall back to implementing it in-session — the human asked for delegation, and that is a different command.
- **More than one candidate and no `--to=`** → ask **ONE** question naming exactly what `--list` found. Never silently pick the first.
- **Dirty tree without `--allow-dirty`** → halt, relay exit `4`. A pre-existing dirty tree makes "what did it touch" unanswerable, and an unanswerable diff is not reviewable.
- **`--read-only` on a CLI that cannot be shown to enforce it** → halt, relay exit `5`, tri-state stated. Two honest ways forward: a different implementer, or an explicit best-effort run (`--accept-unenforced`) that reports `enforcement: unenforceable` and leans on the git tripwire alone. Never present the second as equivalent to the first.
- **`--session=` on a CLI whose resume shape is unverified** → refused (usage error). Guessing a resume flag produces a silent fresh run that looks like a resume, which is worse than a refusal.

## Honesty clause (adjacent to `_orchestration-sync.md`, not inherited)

Every `/delegate` run summary carries a **`Not validated:`** line, and it is never empty just because the gates were green — a gate the implementer reported and you did not re-run counts as **un-run** (G6). The implementer's report is a claim, not evidence.

The read-only **tri-state is never collapsed**. `readOnly.enforcement` ∈ `not-requested` / `enforced` / `unverified` / `unenforceable`; `readOnly.violation` ∈ `true` / `false` / `null`. **`null` is a shippable answer and is never rounded to `false`**, and neither is ever rounded up to "read-only ✓" — that rounding is the single failure this command exists to prevent.

`readOnly.violation: false` is the narrowest claim in the contract and deliberately so: it covers **git-visible paths inside the repo only**. Outside the claim, and therefore outside the guarantee: `.gitignore`d files, anything under `$HOME` or `/tmp`, network calls, a write that was perfectly reverted, and a concurrent change by you in another terminal. The tripwire says the tree moved; it never says nothing else did. `touchedFiles` and the diff are what you review against.

The three-line simple-surface block (`Not validated:` / `Risks:` / `Revert:`) does **not** apply verbatim: `/delegate` commits nothing, so there is no commit range to revert. `Not validated:` comes from this command's own contract, not from the simple-surface mandate.

## Adapter responsibilities

1. **Surface `/delegate` in the native command primitive** when the orchestration surface is selected — same translation rules as every other `commands/*.md` file (Phase 4.8.0), using the dispatcher primitive named in the matrix above. Where the matrix says the tool cannot dispatch (Continue) or cannot dispatch autonomously (Aider), the translation is a NOT-SUPPORTED note or an EXECUTE-NOW preamble, stated as such.
2. **Install `scripts/delegate-relay.sh` into `~/.claude/scripts/`**, the same companion-script obligation every adapter already carries for `validate-*-artifacts.sh` and the `*-parallel.sh` runners. A translated `/delegate` with no relay on disk is a document, not a command.
3. **Preserve the never-commit invariant and the tri-state verbatim.** The relay runs no `git commit` / `push` / `checkout` / `stash`, and the PATH-shimmed `git` handed to the implementer is a **speed bump, not a boundary** (aliases, absolute paths and library calls walk past it) — the brief's no-commit clause and the human's review are the actual control, so a translation that drops either has removed the control, not the ceremony. Likewise G5: **if HEAD moved, the run failed**, regardless of what the implementer reported. A translation that reports "read-only ✓" is the single failure the command exists to prevent.

## The self-dispatch no-op

A `/delegate` inside tool X that resolves `--to=X` is a no-op with extra steps: same vendor, same model family, same blind spots, plus a subprocess and a diff-capture round trip. The invariant is a **different** CLI — that is where the adversarial value comes from.

**Adapters MUST NOT default `--to=` to their own binary.** Omitted `--to=` means *detect*, and if more than one implementer qualifies it means *ask one question*. An adapter that quietly fills in its own tool has turned cross-tool dispatch into an expensive self-call and hidden the fact from the reviewer.

## Adding an implementer

- **New implementer** (a CLI that gains a headless mode): one `case` arm in `impl_profile()` + one in `impl_argv()` in `scripts/delegate-relay.sh`, plus one row in the matrix above — the same contract as `scripts/_parallel-tool-config.sh`. Add it to `KNOWN_IMPLEMENTERS` in the same edit or `--list` will never look for it.
- **No `adapter.md` change is required for that.** Implementers come from `command -v`, not from which adapters this repo ships. The two lists overlap and are not the same list.
- **New tool** (a new adapter folder): add a row above declaring its dispatcher primitive, its implementer binary or an honest "none, and why", and a Cross-references line in its `adapter.md`.
- **Do not upgrade a row on inference.** `host UNKNOWN` (Cline) and `host (partial)` (Codex, Kimi, Windsurf) are conclusions from what this repo has written down. Change them when a file in this repo changes, and cite the line that changed.

## See also

- `commands/delegate.md` — the command: invariants, brief contract, tri-state, gates G1–G7, HALT list.
- `scripts/delegate-relay.sh` — the relay: preflight, launch, watchdog, diff capture, `delegate-relay.result.v1`. `--dry-run` and `--list` are safe anywhere.
- `docs/COMMANDS.md` § `/delegate` — the user-facing summary.
- `templates/tool-adapters/_registry.md` § Top-level orchestration commands → *Cross-tool dispatch*.
- `templates/tool-adapters/_orchestration-sync.md` § `/delegate` — cross-tool dispatch (adapter contract) — the artifact set, the never-commit invariant, the tri-state, and the companion-script obligation, in adapter-facing form. Its § *Not in this table: the integration commands* records why `/delegate` is absent from the command-boundary table, the validator-facts table, and the hook globs.
- `templates/tool-adapters/_task-integration-coverage.md` — the other integration command, and the shape this doc follows.
- `scripts/parallel-fan-out.sh` + `scripts/_parallel-tool-config.sh` — the sibling mechanism: N workers of ONE tool over a ledger. Same "other CLIs are usable" idea, opposite shape (breadth vs. one reviewable diff).

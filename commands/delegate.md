---
description: "Dispatch ONE bounded coding task to a different AI coding CLI, then review its diff and land it. Trigger ONLY when the human names another tool as the implementer — \"have Codex do this\", \"delegate to Cursor\", \"run it through Aider\", \"get a second opinion from another CLI\", \"burn the cheap CLI's quota on this\", \"cross-tool diff\". Anti-triggers (do NOT fire): a plain \"implement X\" with no other tool named (that is /do or the specialist command); \"the repo has an adapter for it\" (adapters CONFIGURE a tool, they do not authorize dispatching to it); fanning an existing ledger out in parallel (that is scripts/*-parallel.sh); wiring a tool up (that is /setup-project-adapters); and any ask not yet reducible to one reviewable diff."
kind: command
pack: orchestration
version: 1.2.0
---

# /delegate <task> [--to=<cli>] [--read-only] [--gate=<cmd>] [--model=<id>] [--session=<id>] [--max-rounds=<N>] [--plan]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md). `/delegate <task> --plan` composes the brief, writes it to `.claude/plans/`, and **exits before any CLI is launched**. The brief *is* the plan artifact, so `--plan` here is the natural dry-run.

**Applies phases: 1–7** (Build/Fix command; Phase 4 = dispatch + capture, not author).

## What this does

Hands ONE bounded task to a **different** AI coding CLI running as a separate process against
this working tree, waits, then gives you the diff to review. The other CLI types; you read,
gate, and commit.

Every other command in this repo *configures* other tools — [`templates/tool-adapters/`](../templates/tool-adapters/)
translates artifacts into 12 tools' native formats so those tools can work standalone.
`/delegate` is the only command that **uses** one. That is the whole point: the adapter tree
is a write path, this is the read-back.

The mechanical half lives in [`scripts/delegate-relay.sh`](../scripts/delegate-relay.sh) — preflight, launch,
watchdog, diff capture, structured JSON. This file owns the judgement half: what is worth
delegating, what the brief must carry, what the tri-state tripwire actually proves, and who
is allowed to commit (you).

## The premise (read this first)

Four invariants. They are not style preferences — a run that breaks one is not a `/delegate` run.
They are adopted from the prior art (`amElnagdy/delegate-skills`) because they are load-bearing,
not because they are conventional.

1. **A separate CLI edits a real working tree, and the diff is the deliverable.** Not an API
   call, not a gateway, not a sub-agent inside this session. If you cannot read the result with
   `git diff`, nothing was delegated.
2. **The relay never commits. The reviewer commits.** `delegate-relay.sh` runs no `git commit`,
   no `git push`, no `git checkout`, no `git stash` — enforced in-script by a subcommand
   allowlist, and pushed at the implementer through a PATH-shimmed `git` that refuses the
   history-writing subcommands. The shim is a **speed bump, not a boundary** (aliases, absolute
   paths, and library calls walk straight past it); the brief's no-commit clause and your review
   are the actual control.
3. **The implementer's report is a claim, not evidence.** "Tests pass" is a sentence it wrote.
   Re-run the gates yourself, and read the diff to the tests before you believe a green one.
4. **Whatever a CLI cannot enforce is said plainly.** No run claims read-only that cannot be
   shown read-only. See the tri-state below — a `null` is a legitimate, reportable answer and is
   never rounded up to `false`.

The corollary the loop is built around: **the separate process has none of this conversation.**
It gets the brief and the tree. Everything load-bearing that lives only in this chat must be
written down or it does not exist.

## When to use

- The human explicitly names another CLI as the implementer ("let Codex do the migration sweep",
  "delegate the test backfill to Aider").
- **Quota / cost routing** — a long mechanical task (a rename cascade, a codemod, a test backfill)
  that does not need this session's context and should burn a cheaper or idler CLI's budget.
- **Adversarial second opinion** — `--read-only` a *different* model over the same code and
  compare its diagnosis to yours. Two vendors disagreeing on the same file is the signal.
- **Cross-tool verification of a plan** — hand `.claude/plans/<file>.md` from any `--plan` run to
  a second CLI and see whether an independent implementer lands the same shape.
- The work is already reduced to one reviewable diff with a stated done-condition.

## When NOT to use

- **No other tool was named.** "Implement X" is `/do`, or the specialist command directly. The
  presence of an adapter under `templates/tool-adapters/` is not a request to delegate — it means
  the tool is *configured*, which is a different verb.
- **Fan-out over an existing ledger** → [`scripts/parallel-fan-out.sh`](../scripts/parallel-fan-out.sh) and its
  `*-parallel.sh` wrappers. Those run N workers of the *same* tool against rows of
  `ai/<pack>/ledger.md`. `/delegate` is one task, one process, one diff, one reviewer.
- **Wiring a tool up** → `/setup-project-adapters`.
- **You want the plan, not the work** → `<command> --plan`, then `/execute-plan`.
- **The task is not bounded yet.** A brief you cannot write in one screen is not delegable —
  narrow it, or run `/refine-prompt` first. Unbounded delegation returns an unreviewable diff,
  which is worse than no diff.
- **The task needs a real host boundary.** Every implementer here edits as your user, with your
  credentials, in your tree. A read-only *flag* is not isolation. If the run must not be able to
  touch the host, use a container or a throwaway worktree — no flag documented here gives you that.
- **The diff would be too large to review honestly.** Delegation whose output you rubber-stamp
  has moved the risk, not reduced it.
- **Against the repository the relay itself lives in.** Refused by default (relay exit 6). The
  artifact directory is written *inside the target tree*, so an implementer that commits there
  commits the relay's own evidence, and a single `git add -A` sweeps brief, logs and shim into the
  same commit. Exercise the relay against a throwaway repo — see *Exercising the relay itself*
  below. The relay-only escape hatch exists for when you genuinely mean it, and stamps
  `selfTarget: true` into the result so the artifact carries the fact.

## Args

- **`<task>`** (required) — the task, in prose. Becomes the body of the brief. One task. If it
  contains "and then", split it and delegate twice.
- Scope paths, gate commands, and constraints are **not** inferred. State them, or pass `--gate=`.

## Flags

| Flag | Effect |
|---|---|
| `--to=<cli>` | Implementer to dispatch to. Omitted → detect what is installed and, if more than one qualifies, ask **one** question. Never silently picks. |
| `--read-only` | Diagnosis / review run: request the implementer's native read-only or plan mode. Refused (exit 5) when that CLI has none — see the tri-state. |
| `--gate=<cmd>` | A real command the implementer must run and you will re-run. Repeatable. Copy them from the project's own config; do not invent a `make test` that does not exist. |
| `--model=<id>` | Pin the implementer's model. **Required for `opencode`** — it has no safe default and the relay refuses to launch without it (exit 2). Optional everywhere else. |
| `--session=<id>` | Resume a prior run of the same CLI with a **delta** brief (rework, not a restatement). Only where the CLI exposes a session id. |
| `--max-rounds=<N>` | Bounded rework loop: after review, dispatch a **fix brief** and re-review, up to N rounds. Default **1** — one dispatch, one review, exactly today's behaviour. Agent-side; the relay has no such flag (see § Rework rounds). |
| `--files=<globs>` | Declare the in-scope paths in the brief. Scoping and review aid — **not** a permission boundary. |
| `--allow-dirty` | Proceed with a dirty tree. The relay fingerprints the pre-existing dirt so touched-files stays a true delta. Default is halt-on-dirty. |
| `--timeout=<dur>` | Watchdog. Default 30m. On expiry the process tree is killed and the partial result is still written. |
| `--dry-run` | Print the resolved implementer, argv, brief and git baseline; launch nothing. |
| `--plan` | Universal handoff flag — write the brief to `.claude/plans/` and exit before dispatch. |

**Two flag surfaces, two vocabularies.** The table above is the *command* surface — what the human types.
`delegate-relay.sh` has its own, and the names are not identical: `--to=` is the command's; the relay's
is **`--implementer=`**, and it rejects `--to=` outright (`unknown arg`, exit 2). `--plan` is likewise
command-only — it is handled in Phase 3.5 and the relay never sees it. Everything else in the table
(`--read-only`, `--gate=`, `--model=`, `--session=`, `--files=`, `--allow-dirty`, `--timeout=`, `--dry-run`)
passes through under the same name. Translations that shell out to the relay must do that rename, or
the run dies at argument parsing before anything is dispatched.

The relay also takes flags this surface does not re-expose: `--accept-unenforced`, `--allow-self`, `--out=`,
`--repo=`, `--brief=`, `--no-commit-shim`, `--quiet`, `--list`. `delegate-relay.sh --help` is the
authority on all of them.

## Implementer matrix

Detected at runtime by `command -v`; never assumed. Flags below are what the relay passes and were
read from each vendor's own docs plus the prior-art skills on **2026-08-20** — CLIs move, so
`delegate-relay.sh` re-probes `<cli> --help` before it claims a read-only mode exists.

| Implementer | Binary | Headless launch (write run) | Native read-only | Resume |
|---|---|---|---|---|
| Claude Code | `claude` | `-p --output-format json --permission-mode acceptEdits`, brief on stdin | `--permission-mode plan` | `--resume <id>` |
| Codex | `codex` | `exec --json --sandbox workspace-write` | `--sandbox read-only` | `exec resume <id>` |
| Cursor Agent | `cursor-agent` | `-p --output-format json --force --trust` | `--plan` (`--mode=plan`) | `--resume <id>` |
| OpenCode | `opencode` | `run --agent build` (needs `--model`) | `--agent plan` | relay: not wired · CLI **has** it (`-c` / `-s <id>`) |
| Aider | `aider` | `--message --yes-always --no-auto-commits --no-dirty-commits --no-suggest-shell-commands --no-detect-urls --no-stream` | `--dry-run` | relay: not wired · CLI: `--restore-chat-history` (repo-scoped) |
| Cline | `cline` | `--json -v --auto-approve true` | `--plan` + `--auto-approve false` | relay: not wired · CLI `--id`, but **broken under `--json`** |
| Gemini CLI | `gemini` | `-p --output-format json --approval-mode yolo` | `--approval-mode plan` | `--resume <id>` |
| Kimi Code | `kimi` | `-p` (headless is always auto-permission; `_parallel-tool-config.sh` still drives it with `--headless --prompt`) | **none** | relay: not wired · CLI docs: `--session <id>` / `-c` |
| Qwen Code | `qwen` | `-p --output-format json --approval-mode yolo` | `--approval-mode plan` *(unverified)* | relay: not wired · CLI docs: `--resume <id>` + `-p` |
| GitHub Copilot | `copilot` | `-p --output-format json --no-color --allow-all-tools` | `--mode plan` | `--resume <id>` |

Three honesty notes, because the rows above are easy to over-read:

- **Aider commits by default.** `--auto-commits` and `--dirty-commits` are both on upstream, and the
  second one commits *your* pre-existing uncommitted work before it starts. The relay pins both off
  and does not expose a way to turn them back on. This is the one implementer where invariant 2 needs
  a flag, not just a brief clause.
- **"relay: not wired" is a statement about the relay, not about the CLI.** It used to read
  "unsupported", which every reader took to mean the CLI could not do it. Measured **2026-08-26**,
  four of the five can, and one is genuinely broken:

  | CLI | What it actually exposes | How that was established | Wireable? |
  |---|---|---|---|
  | `opencode` | `-c` / `--continue`, `-s <id>` / `--session`, on the `run` subcommand the relay already uses | **`opencode run --help`, v1.18.21** — the installed binary, not a doc | **Yes** |
  | `qwen` | `--resume <id>` combined with `-p`; the vendor's own example is a follow-up refactor | Vendor docs (headless mode) | **Yes**, after a `--help` probe |
  | `kimi` | `--session <id>` / `-S`, `--continue` / `-c`, `-r`/`--resume` as hidden aliases | Vendor docs. `--prompt` is documented as incompatible with `--yolo`/`--auto`/`--plan`; `--session` is **absent from that conflict list**, which is not the same as confirmed | **Unknown** — one round-trip test settles it |
  | `aider` | `--restore-chat-history` — restores the repo's chat-history file. **No session id**, so it is repo-scoped, and two concurrent runs in one repo would collide | **`aider --help`, v0.86.2** — the installed binary | **Partly**, with that caveat stated |
  | `cline` | `--id <session>` — but the relay launches cline with `--json`, and [cline#10856](https://github.com/cline/cline/issues/10856) *"`--json` mode can't resume an existing session ID"* has been **OPEN since 2026-05-18** | Vendor issue tracker | **No** — the exact combination is a known bug |

  The rule that produced the old label still holds and is why cline stays out: guessing a resume flag,
  or wiring one whose documented combination is broken, produces a silent fresh run wearing the shape
  of a continuation — worse than a refusal, because the fix brief then addresses a context that was
  never loaded. What changed is the honesty of the label, not the wiring: **no new resume is wired by
  this correction**, and a rework round on any of the five is still a fresh process today.
- **The repo's own [`_registry.md`](../templates/tool-adapters/_registry.md) calls Cursor and Cline "IDE-bound".** That is true of the
  *editor* integration and stale for the *CLIs*: `cursor-agent` and `cline` both ship headless
  binaries, which is why they can be implementers here even though they are not in
  [`scripts/_parallel-tool-config.sh`](../scripts/_parallel-tool-config.sh)'s driver set.

## What happens internally (silent)

**Phase 1 — Understand.** Parse `<task>`. Resolve the implementer: `--to=` wins; else run
`delegate-relay.sh --list` and take the single installed candidate; more than one → ask ONE question
naming what was found. Zero → halt. Confirm the task is one task; if it names two deliverables, say so
and split rather than dispatching a compound brief.

**Phase 2 — Organize.**

```
1. DETECT    — which implementer CLIs exist on PATH (never assume; never invent)
2. PREFLIGHT — git work tree, clean-or-declared-dirty, HEAD recorded
3. BRIEF     — compose the self-contained brief (contract below)
4. BOUND     — scope paths, gate commands, timeout, read-only or write
5. DISPATCH  — relay launches the CLI; blocks; watchdog armed
6. CAPTURE   — diff + touched files + structured result JSON
7. REVIEW    — re-run the gates YOURSELF; read the whole diff
8. LAND      — the human commits; the relay never does
```

**Phase 3 — Retrieve.** ALWAYS reads — see [`templates/snippets/phase-3-always-reads.md`](../templates/snippets/phase-3-always-reads.md).
Two extra reads, because the implementer does not get this session's memory: the target repo's own
agent-instruction files (`CLAUDE.md` / `AGENTS.md` / the tool's own equivalent) and its real gate
commands. Constraints that live only in *this* conversation get copied into the brief verbatim or
they do not survive the process boundary.

**Phase 3.5 — Handoff (`--plan` only).** Write the composed brief to
`.claude/plans/delegate-<slug>-<YYYYMMDD-HHmm>.md`, print path + Plan ID + a one-line summary, exit.
Nothing is dispatched, nothing is edited. Inverse door too: a plan file from any other `--plan` run
is a valid `<task>` here — that is the cross-tool seam the plan format was designed for.

**Phase 4 — Generate (dispatch).** `delegate-relay.sh` takes the brief, verifies the CLI and the git
state, launches the bounded run, and writes `result.json` + `delegate.diff`. It blocks. On timeout it
kills the process tree and still writes a result.

**Phase 5 — Update.** Append one audit line to `ai/_history.md` (create with a `# Task history` header
if absent): `<iso> /delegate <cli> "<task>" → <status> · <N> files · <sessionId|->`. No knowledge-base
writes — nothing is learned until the diff is reviewed and landed.

**Phase 6 — Validate.** The review gate, below. This is the phase people skip, and it is the phase
that makes the whole loop worth running.

**Phase 7 — Improve.** If the same task class is delegated repeatedly with the same corrections, the
brief template is wrong — fix the brief, not the diff. If an implementer repeatedly returns work you
reject, record it and stop routing that class there.

## The brief contract

The separate process has no chat history. A brief is complete when a competent stranger could do the
task from it alone. Mandatory sections:

1. **Task** — one deliverable, in the human's words. Not paraphrased into vagueness.
2. **In scope / out of scope** — paths. Explicit "do not touch" is worth more than "focus on".
3. **Constraints** — every load-bearing rule extracted from this conversation and from the repo's
   agent-instruction files. Whatever is not written here does not exist for the implementer.
4. **Gates** — the project's *real* commands, verbatim. A gate that does not exist teaches the
   implementer to invent a passing one.
5. **Done condition** — observable, checkable by you afterwards.
6. **Report contract** — what to print at the end: what changed, what it could not do, what it is
   unsure about.
7. **The no-commit clause** — appended by the relay, never removable: *do not commit, push, amend,
   checkout, stash, or otherwise move HEAD; leave every change in the working tree.*

**Who writes what.** You write 1-3 and the done condition — they are judgement, and only this session
has them. The relay appends 4 (from `--gate=`), 6, 7, and a working-tree header (repo, branch, HEAD,
`--files=` scope) so those cannot be forgotten or edited away. The composed brief is saved to
`<out>/brief.md`; read it before dispatch under `--dry-run` if the task is expensive.

A brief that cannot state a done condition is not a bounded task. Halt and narrow it.

## Read-only: a tri-state tripwire, not a guarantee

Two independent fields, because "did we ask for read-only", "can this CLI enforce it", and "did
anything change" are three different questions and collapsing them is how false guarantees get made.

**`readOnly.enforcement`** — what the *tool* can do:

| Value | Meaning |
|---|---|
| `not-requested` | a normal write run |
| `enforced` | the CLI documents a native read-only/plan mode, the relay passed it, and `<cli> --help` still advertises it |
| `unverified` | read-only was requested, but the installed binary's help output did not advertise the flag — version drift, or a wrapper. The run is refused unless you accept it |
| `unenforceable` | this CLI documents no read-only mode at all (today: `kimi`). Refused unless you accept it |

**`readOnly.violation`** — what the *tree* shows:

| Value | Meaning |
|---|---|
| `true` | read-only was requested and the post-run git delta is non-empty. Proof a change happened. **Not** proof of who made it |
| `false` | read-only was requested, the pre-run fingerprint was complete, and the delta is empty |
| `null` | not applicable (write run), or coverage was incomplete and the relay will not pretend otherwise |

`false` is the narrowest claim in this document and it is deliberately narrow. It covers
**Git-visible paths inside this repo only**. Outside it, and therefore outside the claim:
`.gitignore`d files, anything under `$HOME` or `/tmp`, network calls, a write that was perfectly
reverted, and a concurrent change by you in another terminal. The tripwire tells you the tree moved.
It never tells you nothing else did. **`touchedFiles` and the diff are what you review against.**

## Gates

| # | Gate | Fails how |
|---|---|---|
| G1 | Git work tree present; **not the relay's own repo**; clean, or dirty-and-declared with `--allow-dirty` | relay exit 4 — or exit 6 for a self-target — nothing launched |
| G2 | Implementer on PATH and `--version` succeeds | relay exit 3, nothing launched |
| G3 | Read-only requested → enforcement is `enforced` | relay exit 5, nothing launched |
| G4 | Brief carries task + scope + constraints + gates + done-condition | agent-side halt before dispatch (not script-enforced) |
| G5 | HEAD unchanged after the run | `violations: ["implementer-moved-head"]`, status `failed` — regardless of what the implementer reported. `git.commits` names what landed; the diff and `touchedFiles` are taken against the pre-run HEAD, so the work is still reviewable |
| G6 | Every `--gate=` command re-run **by you**, on the returned tree | agent-side; a green gate the implementer reported and you did not re-run counts as un-run |
| G7 | Whole diff read against the brief, tests-touched-first | agent-side; report what you did not read |

G5 is mechanical and worth stating twice: **if HEAD moved, the run failed.** The implementer took the
decision that belongs to the reviewer, and no amount of good diff redeems that.

## Rework rounds (`--max-rounds`)

Default is **1**: dispatch once, review once, hand the diff to the human. That is the whole command
and it does not change. `--max-rounds=N` bounds an APPROVED/FIX loop on top of it.

**The loop is agent-side, and it has to be.** Deciding FIX means reading the diff against the brief —
that is judgement, and [`delegate-relay.sh`](../scripts/delegate-relay.sh) is mechanical by design.
The relay has no `--max-rounds`; each round is a separate relay invocation the agent makes. Pushing
this into the script would mean the implementer's own success report deciding whether it succeeded,
which is the exact substitution the tri-state tripwire and G6 exist to prevent.

### One loop, two shapes — and the split is the implementer's, not yours

Round N+1 continues differently depending on whether that CLI exposes a session id
(§ Implementer matrix, *Resume* column):

| | Resume **wired** (`claude`, `codex`, `cursor-agent`, `gemini`, `copilot`) | Resume **not wired** (`opencode`, `aider`, `cline`, `kimi`, `qwen`) |
|---|---|---|
| How round N+1 starts | `--session=<sessionId>` from round N's result JSON | A **fresh process** with no memory of round N |
| What the fix brief carries | A **delta** — the findings only | **Self-contained** — task, current state, findings, what NOT to touch |
| Cost per round | Lower; the implementer keeps its context | Higher; the brief re-establishes everything |

**Never pass `--session=` to a CLI whose resume the relay has not wired** — including the four that
demonstrably HAVE one (§ Implementer matrix, the measured table). The flag surface is the relay's, not
the vendor's: until `build_argv` wires it, `--session=` reaches those CLIs as nothing, and a guessed
resume flag produces a silent fresh run wearing the shape of a continuation. That is worse than a
refusal, because the fix brief then addresses a context that was never loaded. On those five CLIs a fix
round is a **new run**, and the brief is written accordingly. Say which shape a round took in
the summary; a reader who assumes continuity that did not happen misreads every later round.

### What ends the loop

| Outcome | Condition | What you do |
|---|---|---|
| **APPROVED** | Gates re-run green by you (G6) and the diff satisfies the brief (G7) | Stop. Report. **You** commit. |
| **ROUNDS EXHAUSTED** | N rounds spent, still not approved | Stop. Report the surviving findings and the last diff. Do not silently spend an N+1th. |
| **NO PROGRESS** | A round returns an **empty diff**, or the *same* finding survives two consecutive rounds | **Halt the loop immediately.** The brief is wrong, not the implementer — a third attempt at a misunderstood instruction buys nothing. Rewrite the brief or take it back in-house. |
| **HEAD MOVED** | G5 fires in any round | Halt the whole loop, not just that round. Never dispatch a fix round on top of a tree the implementer committed to. |

### Rules that do not relax inside the loop

- **Every round is a full round.** G5, G6 and G7 apply per round. A round whose gates you did not
  re-run yourself is an un-reviewed round, and the loop may not advance past it.
- **The reviewer writes the fix brief.** Never ask the implementer what went wrong and forward its
  answer — that is the implementer grading its own work with an extra step.
- **The loop never commits.** Not on the final round, not on APPROVED. Landing stays the human's,
  which is the invariant the whole command is built around.
- **Findings are cited.** A fix brief that says "tests are failing" without the failing test name and
  `<path:line>` produces another round of guessing. Same cite-or-halt bar as the original brief.
- **`--max-rounds` above 3 is a diagnosis, not a setting.** A task needing four supervised attempts
  was not the ONE bounded task this command takes. Halt and split it.

## HALT conditions

- **No implementer named and none installed** → halt. List what `--list` looked for. Do not fall back
  to implementing it yourself — that is a different command and the human asked for delegation.
- **More than one candidate and no `--to=`** → ask ONE question naming the candidates found.
- **Dirty tree without `--allow-dirty`** → halt. A pre-existing dirty tree makes "what did it touch"
  unanswerable, and an unanswerable diff is not reviewable.
- **`<task>` names two or more deliverables** → halt; split into two runs.
- **Gates unknown** → halt and ask, or run without `--gate=` and say so in the summary under
  `Not validated:`. Never invent a gate command.
- **`--read-only` on a CLI that cannot enforce it** → halt with the tri-state stated (relay exit 5).
  Offer the two honest ways forward: a different implementer, or an explicit best-effort run
  (`delegate-relay.sh --accept-unenforced`), which reports `enforcement: unenforceable` and leans on
  the git tripwire alone. Never present the second as equivalent to the first.
- **HEAD moved during the run** → halt the review. Surface the commits — `git.commits` and
  `<out>/commits.txt` list them by sha and subject — and do not squash them silently. The diff is
  taken against `git.diffBase` (the pre-run HEAD), so the work is still in front of you even though
  it is already in history. `git reset --soft <headBefore>` puts it back in the working tree if you
  want to review it as a diff; that is the reviewer's call to make, and the relay never makes it.
- **Self-target refused (relay exit 6)** → do not reach for `--allow-self` to get past it. Say what
  was refused and why, and offer the throwaway-repo procedure below.
- **Implementer reports success with an empty diff** → halt. Nothing was delegated; report it as a
  failure, not a no-op success.
- **Same finding survives two consecutive rework rounds** → halt the loop. The brief is the defect;
  rewrite it or take the task back. Rounds are not retries.
- **A rework round returns an empty diff** → halt. The implementer either did not understand the fix
  brief or believes it is already done; another round tests neither hypothesis.
- **`--max-rounds` requested above 3** → halt and say why: the task is not bounded, which is a
  splitting problem, not a persistence problem.
- **Diff exceeds what you can review honestly** → halt before landing. Say so out loud and propose a
  narrower re-run.

## What you see (output)

```
/delegate "extract the retry/backoff duplication in src/clients/ into one helper" --to=codex --gate="npm test"

Implementer:   codex 0.5x            (detected: claude, codex, aider)
Mode:          write · sandbox workspace-write
Baseline:      HEAD 1255112 · clean
Brief:         .claude/delegate/2026-08-20-1431/brief.md   (7 sections)
Timeout:       30m

… running …

Status:        completed · exit 0 · 4m12s
HEAD:          1255112 (unchanged) ✓
Touched:       4 files  (+96 / -134)
  M src/clients/http.ts
  M src/clients/queue.ts
  A src/clients/retry.ts
  M src/clients/__tests__/retry.test.ts
Read-only:     not-requested
Session:       01J8… (resume with --session=01J8…)
Result:        .claude/delegate/2026-08-20-1431/result.json
Diff:          .claude/delegate/2026-08-20-1431/delegate.diff

Gates (re-run by me, not by the implementer):
  npm test     ✓ 84/84
Not validated: no lint gate was passed; typecheck not run.
Review:        read the diff before committing. Nothing is staged; nothing is committed.
```

## The result contract

`result.json` is the machine-readable half of the summary above — contract `delegate-relay.result.v1`,
a superset of the prior art's field set so a result from either relay reads the same. The load-bearing
fields:

```json
{
  "status": "completed | failed | timeout",
  "exitCode": 0,
  "signal": null,
  "timedOut": false,
  "selfTarget": false,
  "git": { "headBefore": "…", "headAfter": "…", "headMoved": false, "diffBase": "…",
           "commitsAhead": 0, "commits": [], "committedFiles": [],
           "stagedAtEnd": false, "dirtyAtStart": false, "fingerprintComplete": true },
  "touchedFiles": ["src/clients/retry.ts"],
  "readOnly": { "requested": false, "enforcement": "not-requested",
                "helpProbe": "skipped", "violation": null, "coverage": "…" },
  "commitShim": "enabled", "shimDenials": 0,
  "sessionId": null, "sessionIdSource": null, "resumeHint": null,
  "violations": [], "notes": [],
  "committed": false, "landedBy": null
}
```

`committed` is hard-coded `false` and `landedBy` hard-coded `null`. They are not status fields the
relay might one day fill in — they are the contract stating, in the artifact itself, that landing
happened somewhere else if it happened at all. Read them as *the relay did not commit*, never as
*nothing was committed*: **`git.headMoved` is the field that answers the second question**, and
`git.commitsAhead` / `git.commits` say what landed. A reader who resolves `"committed": false`
against `"headMoved": true` the wrong way concludes the run was a no-op, which is precisely how a
committing implementer used to disappear.

`git.diffBase` is the pre-run HEAD, and `delegate.diff` and `touchedFiles` are both computed
against it rather than against HEAD. That is not a detail: a commit empties `git status` and moves
HEAD onto the implementer's own work, so the two fields a reviewer actually reads would otherwise
go blank at the exact moment the invariant broke — an empty diff that reads like a harmless no-op.
`git.committedFiles` is the file list from `headBefore..headAfter` specifically.

`sessionId` is scanned generically out of the CLI's own JSON output (`session_id` / `threadId` /
`chatId` / `conversationId`). When the CLI prints none, the field is `null` and no id is invented.

## What you DON'T see

No commit. No push. No auto-landing on green gates. The run ends with a working tree and a diff to
read — that is the finished state, not a missing step.

The relay does not stage on your behalf either, but it does not *stop* an implementer from staging:
`git add` is not on the shim's deny list (denying it breaks tools that stage in order to diff). If
the implementer staged, `git.stagedAtEnd` says so and the diff still covers it — `git diff HEAD`
plus a `/dev/null` diff per untracked file, so index state cannot hide a change.

Relay artifacts (brief, logs, diff, `result.json`) default to `.claude/delegate/<ts>-<impl>/` inside
the target repo. They are filtered out of `touchedFiles` and out of the captured diff — the relay
never reports its own output as the implementer's work — and the directory **ignores itself**: it is
created with a `.gitignore` holding a single `*`, so it stays out of `git status` and cannot be swept
into a commit by an implementer running `git add -A`. Artifact files from an older run that are
already *tracked* are outside that protection; untrack those yourself.

## Exercising the relay itself

Testing the relay is a recurring, legitimate need, and the only tree to hand is usually the wrong
one. A run against the repository the relay lives in puts the artifact directory inside the tree
under test, so an implementer that commits commits the relay's own evidence — that is a real
incident, not a hypothetical, and it is why the relay refuses this by default (exit 6).

Build a throwaway repo and a stub implementer instead. Never point it at a repo whose history you
care about, and never at this one:

```bash
SB="$(mktemp -d)"; export HOME="$SB/home"; mkdir -p "$SB/home" "$SB/bin" "$SB/repo"
git -C "$SB/repo" init -q && printf 'seed\n' > "$SB/repo/file.txt"
git -C "$SB/repo" add file.txt && git -C "$SB/repo" commit -qm seed

printf '#!/bin/sh\ncase "$1" in --version) echo stub; exit 0;; esac\nprintf x > a.txt\n' > "$SB/bin/kimi"
chmod +x "$SB/bin/kimi"

PATH="$SB/bin:$PATH" bash scripts/delegate-relay.sh --implementer=kimi \
  --repo="$SB/repo" --brief=<(echo "edit a.txt") --timeout=60
```

`kimi` is the cheapest stub target: its profile declares no read-only mode and no autonomy flag, so
the relay probes nothing beyond `kimi --version` before dispatch.

`scripts/test-delegate-relay.sh` is that procedure as a fixture — nine cases covering the ordinary
run, an implementer that commits behind the shim's back, both alias routes around the shim, the
`git add -A` sweep, two consecutive dry runs, a dirty baseline whose pre-existing dirt must not be
attributed to the implementer, and the self-target refusal (including through a symlinked
invocation, because `scripts/` is symlinked into `~/.claude` and a guard that does not dereference
would no-op exactly there). It builds every repo under `mktemp -d` and refuses to run if a sandbox
path escapes the temp root.

## Failure modes

- **CLI installed but unauthenticated** → it exits non-zero, usually fast. Surface its own error text
  verbatim; do not re-word a vendor auth error into a guess. On macOS a sandboxed parent can block
  Keychain access and make an authenticated CLI report otherwise — re-check outside the sandbox before
  concluding it is logged out.
- **Timeout** → process tree killed, partial result written, `status: "timeout"`. The tree may hold a
  half-finished edit; review it as a diff like any other, or discard it deliberately.
- **Read-only run came back with `violation: true`** → treat the whole run as untrusted output, not as
  a bonus diff. Report it; do not land it.
- **Empty `touchedFiles` with exit 0** → usually a headless permission refusal (an implementer that
  auto-denies tools when not given its autonomy flag) rather than "nothing needed doing". Check the
  captured stdout before believing the no-op.
- **Session resume produced a fresh run** → the id was not accepted. The relay refuses `--session` on
  CLIs whose resume shape it has not verified, precisely so this stays visible.
- **Relay refuses a git subcommand** (`git commit` denied via the PATH shim) → the implementer tried to
  land its own work. That is information about the run. Record it in the summary.
- **The implementer committed anyway** → `git.headMoved: true`, `violations: ["implementer-moved-head"]`,
  status `failed`, `git.commits` listing each sha and subject. The shim is a speed bump: an absolute
  path (`/usr/bin/git`), a libgit2 binding, or a subshell that rebuilds PATH all walk past it, so this
  is a case to expect rather than a surprise. The diff and `touchedFiles` are re-based on the pre-run
  HEAD, so the work is still reviewable — review it exactly as you would any other diff. Hand the
  reviewer the commit list; do not squash the commits and do not present the run as a success.
- **`touchedFiles` empty, `headMoved` true** → the work is in neither the tree nor the commit range.
  History was rewritten, reset, or checked out. The relay says so in `notes` rather than reporting a
  clean run; read `git reflog` in the target repo before concluding anything.

## Hard rules (internal)

- **One task per invocation.** Compound briefs return compound diffs, which review badly.
- **Never commit on the human's behalf, and never stage.** Not on green gates, not on a small diff,
  not when asked nicely mid-run. The commit is the reviewer's, always.
- **Never claim a guarantee the CLI does not provide.** `unverified` and `null` are shippable answers.
  Rounding either to "read-only ✓" is the single failure this command exists to prevent.
- **Detect, never assume.** Implementers come from `command -v`, not from which adapters this repo
  ships. A configured adapter is not an installed CLI.
- **The implementer's report is a claim.** Re-run gates before repeating any of its numbers.
- **Secrets stay out of the brief.** The brief is written to disk and handed to a third-party process.
  Reference `.env` by name; never inline a value.
- **Say what was not validated.** Every run summary carries a `Not validated:` line, and it is never
  empty just because the gates were green.

## Cross-references

- [`scripts/delegate-relay.sh`](../scripts/delegate-relay.sh) — the relay: preflight (`check_git_state`, `check_self_target`,
  `check_implementer`), launch, watchdog, diff capture, `delegate-relay.result.v1` JSON. `--list` is safe
  anywhere; so is `--dry-run`, which composes the brief into a temp directory instead of the target repo
  unless you name an `--out=` yourself, and writes nothing into the tree (it used to write into
  `.claude/delegate/`, which dirtied the tree and made the *next* run refuse with "commit/stash it
  yourself" — the exact pressure that produces a `git add -A`).
- [`scripts/test-delegate-relay.sh`](../scripts/test-delegate-relay.sh) — the relay's fixture: sandboxed repos under `mktemp -d`,
  stub implementers, and the assertions that keep a committing implementer loud instead of silent.
- [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md) — the universal `--plan` contract; the brief doubles as the plan file.
- [`templates/tool-adapters/_registry.md`](../templates/tool-adapters/_registry.md) — the 12 adapters this repo *configures*. Overlaps this command's
  implementer set but is not the same list: `continue` and `windsurf` have no headless CLI, and
  installation is what decides here, not adaptation.
- [`scripts/parallel-fan-out.sh`](../scripts/parallel-fan-out.sh) + [`scripts/_parallel-tool-config.sh`](../scripts/_parallel-tool-config.sh) — the sibling mechanism: N workers of
  ONE tool over a ledger. Same "other CLIs are usable" idea, opposite shape (breadth vs. one reviewable diff).
- [`commands/do.md`](do.md) — routes intent to a command *inside* this tool. `/delegate` routes work *outside* it.
- [`commands/task.md`](task.md) — the other cross-boundary command: `/task` crosses to a task tracker and writes
  status back; `/delegate` crosses to another CLI and brings a diff back.
- **Prior art**: `amElnagdy/delegate-skills` (MIT) — the four invariants, the review-first loop, and the
  tri-state read-only tripwire are adopted from it. That project relays Node-side, one skill per
  implementer; this is one bash relay with a probe-backed profile table, and it inherits this repo's
  `--plan` seam and gate vocabulary.

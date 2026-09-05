---
name: quickstart-verify
description: Execute a README / getting-started / CONTRIBUTING setup section end-to-end in a CLEAN environment to prove onboarding actually works — install → build → run → smoke. Reports per-step pass/fail and time-to-first-green. Distinct from doc-writer, which authors the prose; this one runs it.
kind: skill
pack: documentation
allowed-tools: [Read, Grep, Glob, Bash]
---

# quickstart-verify

## Premise

The failure mode: a getting-started section that *looks* right and doesn't *run*. A missing prereq the maintainer forgot they'd installed years ago, a command renamed two releases back, an env var nobody documented, steps in the wrong order. This is the #1 cause of onboarding abandonment — the new contributor hits step 4, it errors, and they leave. Doc-drift-scan catches docs that reference dead *code*; this catches docs that reference a *procedure* that no longer produces a working checkout.

`smoke-verify` made the same leap for code: a green test suite does not prove the app boots, so it stops trusting the tests and actually starts the process. quickstart-verify makes that leap for onboarding docs: a setup section that reads correctly does not prove a human can follow it, so it stops trusting the prose and actually executes every step in a clean environment.

Cite-or-halt. Every failing step cites **the doc line + the exact command run + the actual error output**. "The setup seems off" is a vibe, not a finding. A failure without the captured command and stderr is not reportable.

Boundary: **doc-writer WRITES the prose; quickstart-verify EXECUTES and PROVES it.** This skill does not author onboarding narrative, restructure the README, or improve wording. It runs the documented steps, and where a step fails it emits the minimal *setup* patch (add the missing prereq, fix the stale command, correct the order). Anything past the setup steps is doc-writer's job.

## When to run

- After editing a getting-started section, `README.md` setup block, or `CONTRIBUTING.md`.
- Before a release — the first thing a new user touches is the quickstart.
- When onboarding a new contributor — run it *as* them, on a machine without your warm state.
- **Not** a substitute for CI. CI validates a pre-baked, cached, correctly-ordered pipeline. This validates the **documented path a human follows by hand** — a different thing, and the gap between them is exactly where onboarding breaks.

## Procedure

1. **Parse the setup section into ordered steps.** Read the getting-started / README / CONTRIBUTING setup block and extract the executable sequence, preserving order:
   - prerequisites (runtime versions, system packages, accounts),
   - clone,
   - install (dependencies),
   - env / config (copy `.env.example`, set required vars),
   - build,
   - run / serve,
   - smoke check (the doc's own "you should now see …").
   Pull commands from fenced code blocks; treat prose imperatives ("install Postgres 15") as steps too.
2. **Provision a CLEAN, isolated environment.** Fresh container / throwaway VM / `git clone` into a tmp dir with a fresh toolchain — **never the current dev machine's warm state.** Warm state (already-installed globals, cached deps, exported vars, a populated DB) is precisely what hides the missing step. The clean env is not optional; it is the mechanism.
3. **Execute each step in order, capturing per-step exit code + stdout + stderr.** Run them exactly as written — same commands, same order, no maintainer shortcuts.
4. **On a failure, pinpoint the doc line vs the missing/stale step.** Diagnose the category: missing prereq, stale/renamed command, undocumented env var, wrong step order, or a step that assumes prior warm state. Stop at the first hard failure (a broken step blocks everything downstream) unless steps are independent.
5. **Measure time-to-first-green** — wall-clock from step 1 to the first successful smoke check. This is the number that predicts whether a new contributor stays; report it even on a full pass.
6. **Tear down** the clean environment.

## Adapt to the codebase

Pick the clean-env mechanism the repo already supports; detect the install/build/run commands from the manifest rather than guessing.

| Clean-env mechanism | Use when | Notes |
|---|---|---|
| `docker run` on a fresh base image | Docker available; want maximum isolation | Closest to a brand-new machine; no host leakage |
| Throwaway container / VM | No Dockerfile but a base image or VM template exists | Snapshot, run, discard |
| `git clone` → tmp dir + fresh toolchain | Lightweight; language toolchain installs cleanly | Use a version manager (nvm/asdf/pyenv) pinned to the documented version, not the host default |
| Devcontainer (`.devcontainer/`) | Repo ships one | Also validates the devcontainer matches the doc |
| Nix shell (`flake.nix` / `shell.nix`) | Repo is Nix-based | `nix develop` gives a hermetic env for free |

Detect the stack's real commands: `package.json` scripts (`jq '.scripts'`), a `Makefile` / `Justfile` / `Taskfile` target list, `pyproject.toml` / `Cargo.toml` / `go.mod`, or the code fences in the README itself. Prefer the documented command over the "correct" one — if the doc says `npm install` but the repo uses pnpm, that mismatch **is** the finding.

## Output

Literal report. Per-step table, then time-to-first-green, then a patch for each failing/missing step.

```
quickstart-verify — CONTRIBUTING.md § Getting Started
Clean env: docker run --rm node:20-slim  ·  5 steps

Step            Doc line              Command                       Result
prereqs         CONTRIBUTING.md:12    node --version                PASS (v20.x)
clone           CONTRIBUTING.md:18    git clone <repo> && cd app    PASS
install         CONTRIBUTING.md:24    npm install                   PASS (38s)
env             CONTRIBUTING.md:31    (none documented)             FAIL
                └ app crashes at boot: "DATABASE_URL is not defined"
                  .env.example lists DATABASE_URL; setup never says to copy it.
build           CONTRIBUTING.md:37    npm run build                 FAIL
                └ error: script "build" not found; package.json has "compile"

Time-to-first-green: NEVER (blocked at step 4 of 5)

Patched getting-started (setup steps only):

  CONTRIBUTING.md:30
+ 4. Copy the example environment file and set the database URL:
+    cp .env.example .env    # then edit DATABASE_URL

  CONTRIBUTING.md:37
- Build the project:  npm run build
+ Build the project:  npm run compile
```

Closure verb: **report-with-fix** when the setup patch fully restores the path, **halt-handoff** when a failure needs a human decision (e.g. an ambiguous rename, or a step that requires a secret the runner can't hold).

## False positives / gotchas

- **Machine-specific prereqs that can't be scripted** — a paid API key, cloud credentials, specific hardware (GPU), an OS-locked SDK. These are **not** failures. Document them as an explicit prerequisite ("Requires a Stripe test key — set `STRIPE_KEY`") and move on. Failing on a secret you were never supposed to have is a false finding.
- **Network flakiness vs a real broken step.** A registry timeout or transient 503 is not stale docs. Retry once; if it passes, it was flaky. Only flag when the failure is deterministic across a clean re-run.
- **"Works on the maintainer's warm machine" is exactly the bug this catches.** If a step passes only because the host already had the tool / var / DB, that is a *missing documented step*, not a pass. This is the entire reason step 2 mandates a clean env — a warm run will green-light broken docs.
- Optional / platform-branching steps ("on macOS run X, on Linux run Y") — run the branch matching the clean env; don't flag the other branch as failed.

## Halt conditions

- Refuse any "the doc is wrong" claim without the **executed command + captured error**. No citation, no finding.
- Do **not** rewrite prose beyond the setup steps — no restructuring, no wording polish, no new sections. That is doc-writer's territory; overreach here corrupts the boundary.
- If a step needs a secret / credential the runner can't have, mark it a **documented prerequisite** — never fail it silently and never fabricate a value to push past it.
- Refuse to report on a warm / current-dev environment. If a clean env cannot be provisioned, halt and say so — a warm-run "pass" is worse than no run, because it certifies broken docs.
- Never edit application source to make a step pass. The setup docs (or a genuinely missing repo file like a `.env.example` entry the docs point to) are the only surface this skill touches.

## Related

- `doc-drift-scan.md` — sibling skill in the documentation pack. It catches docs that reference dead *code* (a renamed symbol, a deleted path); this catches setup docs that reference a broken *procedure* (a missing prereq, a stale command). Same failure family, different surface.
- `@doc-writer` — boundary: doc-writer WRITES the onboarding prose; quickstart-verify EXECUTES and PROVES it runs. This skill never authors narrative or restructures the README.
- `code-quality` `smoke-verify` (cross-pack) — the conceptual parallel. A green test suite doesn't prove the app boots, so smoke-verify boots it; a readable setup section doesn't prove a human can follow it, so quickstart-verify executes it in a clean env.

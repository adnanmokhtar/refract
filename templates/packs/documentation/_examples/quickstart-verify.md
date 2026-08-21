---
name: quickstart-verify
description: Execute a README / getting-started / CONTRIBUTING setup section end-to-end in a CLEAN environment to prove onboarding actually works — install → build → run → smoke. Reports per-step pass/fail and time-to-first-green. Distinct from doc-writer, which authors the prose; this one runs it.
---

# quickstart-verify

A getting-started section that *looks* right but doesn't *run* is the #1 cause of onboarding abandonment. doc-drift-scan catches docs that reference dead *code*; this catches docs that reference a *procedure* that no longer produces a working checkout. Cite-or-halt: every failing step cites the doc line + the exact command + the actual error output.

Boundary: **doc-writer WRITES the prose; quickstart-verify EXECUTES and PROVES it.** It runs the documented steps and emits the minimal *setup* patch where one fails — never restructures the README.

## Premise

The failure mode: a getting-started section that *looks* right and doesn't *run*. A missing prereq the maintainer forgot they'd installed years ago, a command renamed two releases back, an env var nobody documented, steps in the wrong order. This is the #1 cause of onboarding abandonment — the new contributor hits step 4, it errors, and they leave. Doc-drift-scan catches docs that reference dead *code*; this catches docs that reference a *procedure* that no longer produces a working checkout.

`smoke-verify` made the same leap for code: a green test suite does not prove the app boots, so it stops trusting the tests and actually starts the process. quickstart-verify makes that leap for onboarding docs: a setup section that reads correctly does not prove a human can follow it, so it stops trusting the prose and actually executes every step in a clean environment.

Cite-or-halt. Every failing step cites **the doc line + the exact command run + the actual error output**. "The setup seems off" is a vibe, not a finding. A failure without the captured command and stderr is not reportable.

Boundary: **doc-writer WRITES the prose; quickstart-verify EXECUTES and PROVES it.** This skill does not author onboarding narrative, restructure the README, or improve wording. It runs the documented steps, and where a step fails it emits the minimal *setup* patch (add the missing prereq, fix the stale command, correct the order). Anything past the setup steps is doc-writer's job.

## When to run

- After editing a getting-started / `README.md` setup block / `CONTRIBUTING.md`.
- Before a release, and when onboarding a new contributor — run it *as* them.
- **Not** a CI substitute: CI validates a cached, pre-ordered pipeline; this validates the documented path a human follows by hand.

## Procedure

1. Parse the setup section into ordered steps (prereqs, clone, install, env, build, run, smoke).
2. Provision a CLEAN, isolated env — fresh container / VM / tmp clone. Warm state hides the missing step; the clean env is the mechanism.
3. Execute each step in order, capturing per-step exit code + stdout + stderr.
4. On failure, pinpoint doc line vs missing/stale step; categorize (missing prereq, stale command, undocumented env var, wrong order, warm-state assumption).
5. Measure **time-to-first-green** — wall-clock to the first passing smoke check.
6. Tear down.

## Output

```
quickstart-verify — CONTRIBUTING.md § Getting Started
Clean env: docker run --rm node:20-slim  ·  5 steps

Step      Doc line             Command          Result
install   CONTRIBUTING.md:24   npm install      PASS (38s)
env       CONTRIBUTING.md:31   (none documented) FAIL
          └ boot crash: "DATABASE_URL is not defined"; .env.example lists it, setup never copies it.

Time-to-first-green: NEVER (blocked at step 4 of 5)
```

Closure verb: **report-with-fix** when the setup patch restores the path; **halt-handoff** when a failure needs a human decision.

## False positives / gotchas

- Machine-specific prereqs (paid key, cloud creds, GPU) are **documented prerequisites**, not failures.
- Retry a network flake once; only flag deterministic failures.
- A step that passes only on the maintainer's warm machine is a *missing documented step*, not a pass.
- Never edit application source to make a step pass — setup docs are the only surface this touches.

## Halt conditions

- Refuse any "the doc is wrong" claim without the **executed command + captured error**. No citation, no finding.
- Do **not** rewrite prose beyond the setup steps — no restructuring, no wording polish, no new sections. That is doc-writer's territory; overreach here corrupts the boundary.
- If a step needs a secret / credential the runner can't have, mark it a **documented prerequisite** — never fail it silently and never fabricate a value to push past it.
- Refuse to report on a warm / current-dev environment. If a clean env cannot be provisioned, halt and say so — a warm-run "pass" is worse than no run, because it certifies broken docs.
- Never edit application source to make a step pass. The setup docs (or a genuinely missing repo file like a `.env.example` entry the docs point to) are the only surface this skill touches.

## Related

- `doc-drift-scan.md` — sibling skill; it catches docs pointing at dead *code*, this catches setup docs pointing at a broken *procedure*.
- `@doc-writer` — boundary: doc-writer writes the onboarding prose; quickstart-verify proves it runs.
- `code-quality` `smoke-verify` — the conceptual parallel: a green suite doesn't prove the app boots, so smoke-verify boots it; a readable setup doesn't prove a human can follow it, so this executes it.

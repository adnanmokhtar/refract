---
description: Orchestrate a feature that spans multiple sibling repos — contract-first, dependency-ordered, with end-to-end verification that every consumer matches the shipped contract. Producer (shared lib / API) ships first and backward-compatible; consumers follow.
---

# /cross-repo-task

## The Premise (read this first)

**Both repos' state is real. Don't assume; read both before proposing.** The most common failure mode for cross-repo work is editing repo A based on a stale assumption of repo B's contract — then the change ships, the contract didn't match, and someone rolls back two repos. Capture state from EVERY affected sibling before writing any spec.

**The contract is the deliverable, not an afterthought.** Before any consumer code is written, the exact shape of each changed boundary — path + method + request + response + error envelope, or the shared type / schema definition — is written down and approved. Every repo builds against THAT one artifact, never a paraphrase of it. A consumer coded against an assumed shape is the rollback trap this command exists to prevent.

**A contract change can break repos that aren't in your task.** An endpoint or shared type you change may already be consumed by a sibling you weren't planning to touch. Identify every existing consumer before you change the shape — not just the ones in scope.

**Mechanical halt** — refuse to advance past the impact-matrix step unless:
- `git status` was captured for every affected sibling repo (clean tree confirmed, branch surfaced).
- Each sibling's root `CLAUDE.md` was Read in this session (per-repo conventions don't auto-load across boundaries).
- Branch state per repo is recorded in the spec (which branch you'll commit to, and whether it's already up-to-date with origin).
- Every existing consumer of a contract you intend to change is identified (grep the workspace for callers of the endpoint / importers of the shared type) — including repos not otherwise in scope.

**No assumed state. No paraphrased contracts. Cite, don't summarize.**

## When to use / NOT to use

- USE: a feature requiring coordinated changes across 2+ repos in the workspace.
- NOT: a single-repo change — use that repo's own `/add-feature` / `/fix-bug`.
- NOT: tracking a port that's *blocked waiting* on another repo to ship first — that's the migration pack's `/cross-repo-task` registry (register / list / drain), a different command with the same name.

## Flow

1. **Understand the task** — ask the user for the feature description if not given.
2. **Read `PROJECTS.md`** — know every sibling's stack + role.
3. **Build impact matrix**: which repos are affected and why, in **dependency order** (shared lib → API → consuming frontends/services). For every contract you'll change, list **all** existing consumers found in the workspace, including out-of-scope repos. Present to user for approval.
4. **Contract-first (gate)** — before any code, write the explicit contract for each changed boundary: path + method + request body + response body + error shape (or the shared type / schema). Classify each change **additive** or **breaking**. A breaking change to a contract used by a repo **not in scope** HALTS — either version it (new endpoint / `/v2`, deprecate the old) or bring that consumer into scope. Get the contract approved. This artifact is the single source every repo codes against.
5. **Write spec** to `specs/<YYYYMMDD-slug>.md` at workspace root — includes the approved contract, the dependency order, and per-repo branch state.
6. **Execute in dependency order**:
   - **Producer FIRST** (shared lib / API) — implement the contract exactly. Keep it **backward-compatible** so consumers can land in a separate PR without breaking production; if it genuinely can't be additive, ship behind a version or flag. Add DTOs, endpoints, migrations, tests.
   - **Then consumers** — build against the contract artifact (generate types from it where the stack supports it; otherwise type the boundary by hand from the contract, not from memory). Add i18n keys in every locale that repo supports.
7. **Per repo**: `Read` its `CLAUDE.md` FIRST, then apply changes using its conventions. If a repo adds a dependency it doesn't already use, run a dependency review (maintenance / license / size / supply-chain) before installing — no silent cross-repo `npm install`.
8. **Verify end-to-end** — for each consumer, confirm it matches the producer's **actually shipped** shape, not the spec on paper: generated/checked types, a real call against the running producer, or a contract test. A green consumer build alone does not prove the shapes match.
9. **Final report**: per-repo diff summary + contract summary (additive/breaking per boundary) + the linked-PR set (which PRs ship together) + i18n keys added + the end-to-end verification result + follow-ups + a one-line half-shipped recovery note.

## Rules

- Never commit across repos in one step. Edit all affected repos, then commit each separately; leave commit approval to the user.
- Contract approved before any consumer code. No consumer built against a paraphrase or a remembered shape.
- **Producer ships backward-compatible (or behind a version/flag).** You cannot merge two repos' PRs atomically — so a breaking contract change that requires both to land at once is forbidden. Additive-first lets the consumer PR merge on its own schedule.
- A breaking change to a contract consumed by an out-of-scope repo halts: version it or widen scope. Never silently change a shape a third repo depends on.
- Flag any frontend change that depends on an API change that isn't shipped yet.
- New dependency in any repo gets a dependency review — a cross-repo feature is not licence to grow three dependency trees silently.
- Linked PRs reference each other in their descriptions so reviewers know they ship together.
- For UI changes, remind the user to run visual verification inside that repo's own session.

## Failure modes

- **Producer merged, consumer not** — safe only if the producer was additive / backward-compatible. If it wasn't, that's the two-repo rollback trap; the version/flag rule prevents it.
- **Consumer built against an assumed shape** — prevented by the contract-first gate (step 4) + the end-to-end verification (step 8).
- **A third repo not in scope breaks** — prevented by identifying every existing consumer in step 3 + the breaking-change halt in step 4.
- **i18n key drift across frontends** — same concept must use the same key name across repos; missing-locale is a silent break.
- **Stale branch on a sibling** — caught by the impact-matrix mechanical halt (branch state recorded per repo).

## Related

- `.claude/rules/workspace.md` — the workspace discipline this command enforces.
- The migration pack's `/cross-repo-task` — same name, different job: a registry for tracking ports blocked on upstream repos.

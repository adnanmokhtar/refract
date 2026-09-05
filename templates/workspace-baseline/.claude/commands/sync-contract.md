---
description: After an API contract change, find frontend consumers and propose synced edits.
kind: command
pack: workspace-baseline
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /sync-contract

Derive the contract diff from the producer repo, classify each changed field additive-or-breaking, enumerate every consumer across the registered siblings, and report the synced edits. Reports, never applies.

## The Premise (read this first)

**Source contract wins. Refuse drift; surface every divergence with cite.** The API DTO / endpoint signature is the source of truth. Consumers must align — not the other way around. Every proposed edit cites both sides: `<producer-repo>/<contract-file:line>` (truth) and `<consumer-repo>/<consumer-file:line>` (drift).

**Derive the change; do not interview the user for it.** The producer repo already contains the diff — in its git history, its spec file, or its DTO. Asking "what changed?" and working from the answer means the report covers only what the human remembered, and the field they forgot is exactly the one that breaks in production. Ask only when derivation genuinely fails, and say which derivation was tried.

**Mechanical halt** — refuse to emit:
- A consumer edit without the exact consumer `file:line` that is drifting.
- A paraphrased contract change ("rename this field" — name the OLD and NEW field exactly, with types).
- A "looks fine" verdict on a consumer without citing the line that consumes the changed field.
- A verdict of "no consumers affected" without showing the searches that returned empty (§ Enumerate).
- Hand-wave enumeration (`etc.`, `...`, `and similar`) — list every site or halt.

If a consumer change requires a producer change first, halt — never patch a consumer around a missing producer change.

## 1. Establish the change (derive, in this order)

Stop at the first rung that yields a concrete old-vs-new shape. Record which rung fired.

| Rung | How | Yields |
|---|---|---|
| Committed spec diff | `git -C <producer> diff <base>..HEAD -- '*openapi*' '*swagger*' '*.proto' '*.graphql'` | Field-level old vs new, authoritative |
| DTO / serializer diff | `git -C <producer> diff <base>..HEAD -- <dto-or-serializer-paths>` | Field-level old vs new |
| Uncommitted working tree | same commands without `<base>..HEAD` | The change in progress |
| Spec-vs-spec | Compare the committed spec against the previously published one | Field-level, when history is squashed |
| **Ask** | Endpoint path or DTO name + what changed | Last resort — **state in the report that the change set is user-supplied and may be incomplete** |

`<base>` defaults to the producer's last deploy tag or `origin/HEAD`, whichever the repo records. Read the producer's `CLAUDE.md` first — it names the contract's real location when the layout is not obvious.

Write the change set as a table before touching any consumer. One row per field. No row, no edit:

| Endpoint / type | Field | Was | Now | Class |
|---|---|---|---|---|
| `<path>` / `<TypeName>` | `<field>` | `<type / present>` | `<type / removed>` | additive \| breaking |

## 2. Classify each row

Use the backend pack's **`api-contract.md § Evolution rules`** table when that pack is co-installed in the producer repo — it is the single classification of safe vs breaking and this command does not restate it. **Absent** → apply the same defaults and say you did: adding an optional response field, a new endpoint, or an optional input field is additive; removing or renaming a response field, changing a field's type, adding a required input field, tightening validation, or changing an error code is breaking.

A breaking row consumed by a repo **not** in this run's scope is a halt: version it, or widen the scope. Never silently change a shape a third repo depends on.

## 3. Enumerate consumers (every registered sibling, not just the obvious one)

Read `PROJECTS.md` and search **every** repo whose role is a consumer — a workspace usually has more than one, and the forgotten admin panel is a real outage. For each repo and each changed row:

```bash
rg -n --hidden -g '!node_modules' -g '!dist' -g '!*.lock' \
   -e '<endpoint-path>' -e '<TypeName>' -e '<field-name>' <consumer-repo>/
```

Search all four, because they miss different things:
1. **The endpoint path** — finds the call sites (including string-built URLs; try the path minus its prefix too).
2. **The type name** — finds generated and hand-written type declarations.
3. **The field name** — finds destructuring, property access, template bindings, and test fixtures the type search misses.
4. **Generated-client artifacts** — a checked-in generated client is a consumer that no field search will hit if it is stale. Note its generation command; a regenerate is the fix, not a hand edit.

Record per repo: searched (yes/no), hits, and **empty results explicitly**. "No hits in `<repo>` for all four searches" is a finding; a silently omitted repo is a gap.

## 4. Verify against the shipped shape

**A green consumer build does not prove the shapes match.** A hand-written client type compiles perfectly against a field the producer stopped sending. State which lane applies per consumer:

| Consumer's type source | Verification | Lane label |
|---|---|---|
| Generated from the spec | Regenerate, then typecheck — the diff IS the impact list | `verified: regenerated` |
| Shared type package | Bump, then typecheck both sides | `verified: shared-types` |
| Contract test present | Run it against the producer's new shape | `verified: contract-test` |
| Hand-written types | Typecheck catches renames, **never** a removed field still declared optional | `unverified: hand-written` |
| None of the above | — | `unverified: none` |

`unverified` is a reportable state, not a failure of this command — but it must appear in the output. A report that omits it implies a verification that never ran.

## 5. Output

```
CONTRACT SYNC — <producer-repo> → <N> consumer(s)
Change set derived from: <rung>              Base: <ref>

CHANGES
  <endpoint/type>.<field>: <was> → <now>     [breaking]

PER-REPO IMPACT
  <consumer-repo>   [<lane label>]
    <file:line>  <one-line excerpt>          → <exact edit>
    <file:line>  <one-line excerpt>          → <exact edit>
    i18n keys to add: <key> (<locales>)
  <consumer-repo>   searched, 0 hits (4/4 searches empty)

BLOCKED
  <repo> — consumes <field>, out of scope this run: version or widen scope

NEXT: /cross-repo-task to execute — producer ships first, backward-compatible.
```

## Rules

- **Report, never apply.** This command proposes; `/cross-repo-task` executes in dependency order.
- **Producer first and backward-compatible.** PRs in different repos cannot merge atomically, so a change requiring two repos to land at once is forbidden — additive-first lets each consumer merge on its own schedule.
- Flag consumers that break **silently**: an optional field becoming required, a widened union, a nullable turning non-null, an error code a client keys on.
- Every user-facing string a consumer edit adds goes into **every** locale that consumer ships.
- One `## Commits` reminder: each sibling has its own remote; edits land per repo, reviewed separately.

## Related

- `@api-contract-sentry` — *frontend pack, in the consumer repo, when co-installed.* The local version of this question: one frontend, deep enumeration. This command is the workspace fan-out across N consumers; hand off to the sentry when one repo needs the exhaustive per-site walk.
- `api-contract.md` § Evolution rules — *backend pack, in the producer repo, when co-installed.* Owns the additive-vs-breaking classification used in step 2.
- `/cross-repo-task` — executes the punch list this command produces.
- `.claude/rules/workspace.md` § Contract-first — the standing rule this command operationalizes.

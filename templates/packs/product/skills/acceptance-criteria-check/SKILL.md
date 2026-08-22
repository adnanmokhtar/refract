---
name: acceptance-criteria-check
description: Test every acceptance criterion mechanically for falsifiability, observability, and boundedness — for each one, name the observation that would prove it FAILED, or report it as unverifiable. Run before estimation, before build, and whenever "done" was disputed. Tests whether a criterion CAN be checked — `evidence-trace` tests whether the requirement should exist at all, and `assumption-ledger` turns what is unsourced into ranked tests.
---

# Skill: acceptance-criteria-check

## Premise

A criterion is verifiable when someone who was not in the room can observe whether it holds. The test is mechanical and produces the same answer for every reviewer: **name the observation that would prove this criterion FAILED**. If no such observation exists, the criterion cannot be verified and the disagreement about "done" is scheduled for after delivery instead of now.

Every criterion in scope gets a row. There is no sampling: an unchecked criterion has been silently accepted.

## Halt conditions

- **No acceptance criteria exist** — the spec has prose but nothing testable. That is the finding; report it and stop rather than inventing criteria, because invented criteria become the contract.
- **The actor is unstated** across the criteria set — "the system shall" hides who, and the answer changes what is being tested.
- **The surface cannot be located** for criteria that modify an existing surface. "Changed to X" cannot be tested without knowing what it changed from — but where the repository is readable, that is something to **go and read**, not to halt on: find the surface, record today's behaviour at `<file:line>`, and test the criteria against it. The criterion's failure to state the prior behaviour stays a finding (it is unbounded as written). The halt is for the case where neither the criteria nor the codebase identifies what X is, because then the criterion has no referent.
- **Criteria reference an external standard** that is not reachable — record them as `DEFERRED — standard not available`, not as passing.

## When to run

- Before estimation, so ambiguity is priced out rather than in.
- Before build, as the last gate on the spec.
- After a dispute about whether something was done, to identify which criterion caused it.
- On a backlog being inherited, to size the requirement debt.

## Procedure

### 0. Establish the prior behaviour (for criteria that modify an existing surface)

Locate the surface and record what it does today, cited at `<file:line>` — the states, the errors already returned, the limits already enforced. This is not scope creep into implementation review; it is what makes the boundedness test in step 2 decidable. "Loads faster than before" has no bound in prose and acquires one the moment "before" is a measurable value, and the same is true of every criterion phrased as a delta. Record `NOT APPLICABLE — new surface` where the surface does not exist yet; the rest of the procedure is unchanged.

### 1. Enumerate

Extract every criterion, verbatim, with its locator. Include criteria embedded in prose — a sentence beginning "it should also" is a criterion wearing a narrative disguise, and it will be built or not built at random.

### 2. Apply the four tests to each

| Test | Question | Fails when |
|---|---|---|
| **Falsifiable** | what observation would prove this FAILED? | no observation could refute it |
| **Observable** | can it be checked without asking the author? | verification requires the author's intent |
| **Bounded** | are the numbers, volumes, and conditions stated? | an adjective stands where a bound belongs |
| **Singular** | is this one criterion? | it contains "and" joining independently-testable claims |

The singular test matters more than it looks: a compound criterion passes when half of it is met, and the argument that follows is unresolvable because both parties are right about their half.

### 3. Classify the failures

| Class | Shape | Replacement |
|---|---|---|
| **unbounded adjective** | fast, responsive, intuitive, easy, robust | a number, a percentile, a measurement point, a load condition |
| **deferred standard** | properly, correctly, appropriately, as expected | name the standard, or state the behaviour |
| **capability not behaviour** | "should be able to" | the observable outcome |
| **blanket error clause** | "handles errors gracefully" | one criterion per named failure, each with its observable outcome |
| **compound** | two claims joined by "and" | split |
| **intent-dependent** | "the user understands that…" | an observable proxy, or move it out of acceptance criteria |
| **circular** | "works as expected" | state the expectation |

### 4. Check the numbers that are present

A number is not automatically a bound. Each numeric criterion needs:
- a **unit** (seconds? milliseconds? business days?)
- a **percentile** where it is a distribution (p50 and p99 are different products)
- a **measurement point** (server-side, client-side, end-to-end, cold or warm)
- a **load condition** (at what concurrency, at what data volume)

A latency criterion missing the percentile and the measurement point is unbounded despite containing a number, and this is the most common way an unverifiable criterion passes review.

### 5. Report

```
## acceptance-criteria-check — <spec> — <date>

| #    | Criterion (verbatim)                     | Falsifiable | Observable | Bounded | Singular | Refuting observation | Class |
|------|------------------------------------------|-------------|------------|---------|----------|----------------------|-------|

Totals: <n> criteria · pass <n> · fail <n>
Failure classes: unbounded <n> · deferred-standard <n> · capability <n> · blanket-error <n> ·
                 compound <n> · intent-dependent <n> · circular <n>

Criteria embedded in prose (extracted): <n>
Numeric criteria missing unit / percentile / measurement point / load condition: <n> (named)

Verdict: VERIFIABLE | PARTIALLY VERIFIABLE (<n> failing) | NOT VERIFIABLE
```

## Inputs

- The spec, ticket, or criteria set with locators.
- The documented current behaviour, for criteria modifying an existing surface.
- The domain vocabulary (`ai/business-domain.md`), to flag invented terms.

## Outputs

- The criteria ledger, pasted verbatim into `/audit-requirements`'s output — it is the sole source for that command's falsifiability column.
- A replacement proposal per failing criterion, in a separate section marked as a proposal.

## False positives / gotchas

- **Flagging a bounded adjective.** "Fast (p95 under 300ms measured server-side at 500 concurrent requests)" contains "fast" and is fully bounded. Read the surrounding text before flagging on a keyword.
- **Demanding a number where a behaviour is the right answer.** "The list shows the ten most recent" needs no percentile.
- **Treating a cross-reference as unbounded.** A criterion pointing to a documented standard is bounded if the standard is reachable — check, then record `DEFERRED` only if it is not.
- **Splitting a genuinely atomic criterion** because it contains "and" ("saves and returns to the list" may be one user-visible outcome). Split only when the halves are independently testable and could diverge.
- **Verifying against the implementation.** Criteria written after the code, restating what was built, pass every test here and are worthless — check the authoring order and say so.
- **Assuming an unstated actor is "any user".** That assumption is exactly the defect.

## Related

### Skills
- `evidence-trace` — whether the requirement should exist; this skill tests whether it can be checked.
- `assumption-ledger` — unsourced requirements become ranked tests.
- `launch-readiness` — the pre-launch gate that assumes these criteria were verifiable.

### Agents
- `@requirements-reviewer` — issues the verdict; this skill supplies the ledger.
- `@scope-arbiter` — an unverifiable criterion cannot be sized reliably.

### Commands
- `/audit-requirements` — dispatches this skill.
- `/define-success` — the metric criteria this skill cannot bound without.

### Patterns
- `ai/patterns/acceptance-criteria.md`

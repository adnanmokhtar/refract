---
name: mobile-api-contract
description: Pattern — designing and changing a server contract for clients you cannot redeploy. Additive-only discipline, tolerant client parsing, version negotiation, the minimum-supported-version gate as a product decision, kill switches, and the sunset protocol that measures the installed-version distribution before removing anything.
kind: ai-pattern
pack: mobile
---

# Pattern: Mobile API contract

> **Hard rule:** A shipped mobile client is permanent until its user chooses to update. Every server change that a shipped client can observe MUST be **additive**, every client MUST parse **tolerantly** (ignore unknown fields, survive missing optional ones), and nothing may be removed from the contract until the **installed-version distribution** has been measured and the remaining share is an accepted, recorded product decision. Deleting a field, renaming one, narrowing a type, or tightening validation because "the app has been updated" is forbidden.

**When to apply**
- Designing or changing any server endpoint that a released mobile client calls.
- Setting or raising a minimum supported app version.
- Removing, renaming, or re-typing anything in a response a shipped client reads.
- Introducing a kill switch, remote config flag, or server-driven feature gate that a mobile client obeys.

**When NOT to apply**
- API design for a web client you deploy alongside the server — the `backend` pack owns general API design, and a browser reload fixes what a mobile release cannot.
- Delivering a JS-layer fix without a store release — `ota-updates` owns the mechanism and its native-vs-JS boundary.
- Retry, backoff, and queue semantics on the client — `offline-sync` owns those.
- Internal service-to-service contracts with no mobile consumer.

**Halt conditions / mandatory cites**
- Any change to a response shape MUST cite whether a **shipped** client reads that field, at `<path:line>` in the client, or state explicitly that the field is new and unread.
- Any removal MUST cite the **measured installed-version distribution** and the date it was measured. "Everyone has updated" without a number is a rejection, not a plan.
- Any minimum-supported-version raise MUST cite BOTH the gate's server source AND the client's forced-update screen, including its **store escape hatch** — a version gate with no way forward bricks the install.
- Any tolerant-parsing claim MUST cite the decoder configuration or the model definition proving unknown fields are ignored — a strict decoder is a future crash on a field you have not added yet.
- A doc proposing a "breaking change with a coordinated client release" MUST cite why the additive path was rejected; coordination does not reach users who do not update.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming a change is backward compatible.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Mobile` and the server's API docs.
>
> - **Contract source of truth**: `<OpenAPI spec / schema file / generated client>`
> - **Client version header**: `<header name the client sends on every request>`
> - **Min-supported-version source**: `<remote config key / API response field / endpoint>`
> - **Forced-update screen**: `<file path>`
> - **Kill-switch / remote-config provider**: `<name + the flags that gate mobile features>`
> - **Installed-version telemetry**: `<where the version distribution is read from>`

## Why this pattern matters

Server teams reason in deploys; mobile reasons in installs. The gap between those two mental models is where this pattern lives, and it fails in both directions.

**"We'll ship a client fix"** is the optimistic failure. It assumes an update reaches users on the server team's timeline. It does not: the release must be built, reviewed, published, and then *chosen* by each user. Apple publishes that "on average, 90% of submissions are reviewed in less than 24 hours" ([App Review](https://developer.apple.com/distribute/app-review/)) — that is the fastest link in the chain, and it is not the binding one. Adoption is. A user who has auto-update off, or who is on a device that no longer receives your build, keeps running your old client indefinitely.

**"We can never change anything"** is the pessimistic failure, and it produces `v2`, `v3`, `v4` of every endpoint, each with its own handlers, tests and bugs, none ever retired because nobody measured who is still on `v1`. The freeze is not caution; it is deferred work with compound interest.

The way through is not a version number. It is: **make changes additive so old clients keep working, make clients tolerant so new fields do not break them, and make removal a measured decision rather than an assumption.**

## What "breaking" means for a client you cannot redeploy

The definition is stricter than the server's usual one, because the failure mode is a crash on a device you cannot reach.

| Server change | Safe for shipped clients? | Why |
|---|---|---|
| Add a new optional field to a response | **Safe** — provided clients ignore unknown fields | The oldest client never looks at it. |
| Add a new endpoint | **Safe** | Nothing old calls it. |
| Add a new optional request parameter with a server-side default | **Safe** | Old clients omit it and get the old behaviour. |
| Add a new enum value | **Breaking** unless clients have an unknown-case fallback | A strict enum decode throws on the value you just added. |
| Remove a field | **Breaking** | An old client reading a now-absent required field fails to decode the whole response. |
| Rename a field | **Breaking** — it is a remove plus an add | Ship both, migrate, then remove under the sunset protocol. |
| Narrow a type (string → int, nullable → required) | **Breaking** | Decoders are stricter than humans expect. |
| Tighten request validation | **Breaking** | An old client sends what used to be accepted and now gets a 4xx it has no branch for. |
| Change an error code or error body shape | **Breaking** | Old clients branch on the old shape; the new one falls through to a generic failure. |
| Change pagination semantics or default page size | **Breaking in effect** | Old clients paginate against assumptions that no longer hold. |
| Change a default value | **Breaking in effect** | Behaviour changes under a client that never asked for it. |

**The rule that follows:** the contract only ever grows. Removal is a separate, scheduled, measured operation — never a side effect of adding.

## Tolerant client parsing

Half of the additive discipline lives on the client, and it must be in place *before* the server needs it — tolerance added in version 12 does nothing for version 11.

- **Ignore unknown fields.** Configure the decoder to skip them rather than fail. This is a one-line setting in most stacks and it is the single highest-leverage line in this pattern.
- **Every new field is optional in the client model**, even when the server swears it is always present. Servers roll back; feature flags disable code paths; a field that is always present today is absent during an incident.
- **Every enum has an unknown case.** Decode to it rather than throwing, and design the UI to render an unknown case as "something new, tap to update" rather than a crash or an empty screen.
- **Never decode into a type that throws on partial data.** Prefer a decode that yields a usable object with gaps over one that fails whole-response.
- **Log unknown-field and unknown-enum encounters** with the client version attached. That log is the earliest signal that a server change is reaching a client generation you did not think about.
- **Do not validate the server's response shape on the client beyond what you render.** Every extra assertion is a future incident.

## Version negotiation and the server's obligation

- **Every request carries the client version.** A header with app version, build number and platform, sent from a single networking layer — not per-call, not sometimes. Without it, none of the measurement in this pattern is possible, and the server cannot make a compatibility decision it needs to make.
- **The server may branch on that version — sparingly.** Version branching is legitimate for shaping a response an old client can consume; it is not a licence to keep two behaviours forever. Every branch carries the version it exists for and the condition under which it can be deleted.
- **Old shapes stay alive on their own timetable.** The server's obligation is not "forever"; it is "until the sunset protocol says otherwise", which is a decision with a date and a number behind it.
- **Prefer additive shape-widening to version branching.** One response that contains both the old and new fields is simpler to reason about and to retire than two code paths.

## The minimum-supported-version gate

The gate is a **product decision wearing an engineering costume**. Engineering supplies the mechanism and the measurement; the product owner accepts the cost of locking out a share of the installed base.

- **The mechanism:** the client asks the server (a config key, an endpoint, or a response header) for the minimum version still accepted. Below it, the client shows a blocking screen.
- **The escape hatch is mandatory.** The blocking screen must link to the store listing. A gate with no route to a newer build is a bricked install, and it is the most user-hostile bug this pattern can produce.
- **The gate cannot be delivered by the JS layer alone** when the required change is native — `ota-updates` owns that boundary and states it plainly. Do not design a gate whose remedy your delivery mechanism cannot ship.
- **Raise it only for real breakage:** a removed API the old client cannot survive, a security fix, a data-format change that corrupts on old clients. Convenience is not a reason to lock people out.
- **Announce before you enforce.** A soft, dismissible prompt for a release or two, then the hard gate — measured, so you know how much of the base the hard gate will actually catch.

## Kill switches and remote config

A store release is the slowest tool you own. For anything you might need to turn off in a hurry, the gate belongs on the server side of the wire.

- **Every risky feature ships behind a server-readable flag** — a new payment path, a new sync engine, a new native integration. The flag is read at launch and on foreground, cached with a stale value that is safe.
- **The safe default is "off" when the flag cannot be fetched.** A client that fails open on a feature you were trying to disable has no kill switch, only a config file.
- **A kill switch is not a rollback.** It stops the damage; the fix still ships through the normal release path.
- **Do not let flags accumulate.** Every flag has an owner and a removal condition, or the client becomes a matrix of untested combinations.

## The sunset protocol

Removal is allowed. Removal *by assumption* is not. The protocol is four steps and the first one is the whole point.

1. **Measure.** Read the installed-version distribution from the client-version header or store telemetry. Write down the share still on the shape you want to remove, and the date measured.
2. **Decide, and record.** The product owner accepts the residual share. "We are cutting off N% of active installs on this date" is the sentence that has to be said out loud and written down — this is exactly the decision that gets skipped, and skipping it is how a removal becomes an incident.
3. **Warn in-app, then gate.** Soft prompt for the affected versions, then the minimum-supported-version gate with its store escape hatch, then removal.
4. **Remove, and watch.** Delete the old shape only after the gate has been enforced for a full release cycle, and watch error rates for the client generation you just cut off — the measurement is stale the moment you take it, and the residual share is never quite zero.

**A removal with no measurement is a rejection, not a task.** This is the one place this pattern refuses to be flexible, because the cost lands on users who did nothing wrong.

## Adapt to the codebase

| Concern | Where it lives, whatever the stack |
|---|---|
| Client version header | One networking layer / interceptor — never per call site |
| Tolerant decoding | The decoder configuration or generated-model settings, once, globally |
| Unknown-enum fallback | The shared model layer, not per screen |
| Min-version gate | One launch-and-foreground check, one blocking screen, one store link |
| Remote flags | One config client with a safe-default table |
| Contract source of truth | A schema the server owns and the client generates from, where the stack supports it |

If the project generates its client from a server schema, the generator's strictness settings *are* the tolerant-parsing policy — check them, because the defaults are usually strict.

## Detectors (cite-or-halt)

1. **No client-version header.**
   - BAD: requests carry no app version, so no measurement and no server-side compatibility decision is possible.
   - GOOD: one interceptor attaches version + build + platform to every request.
   - `grep -rniE "interceptor|defaultHeaders|addHeader|setRequestHeader|httpClient" src/ app/ lib/` — then confirm a version header is set in exactly one place.
2. **Strict decoding.**
   - BAD: a decoder that throws on unknown keys, or models with non-optional fields for everything the server "always" sends.
   - GOOD: unknown keys ignored; new fields optional.
   - `grep -rniE "JSONDecoder|jsonSerializable|fromJson|Codable|@Serializable|zod|superstruct|ignoreUnknown" src/ app/ lib/` — inspect the strictness setting.
3. **Enum with no unknown case.**
   - BAD: a closed enum decoded straight from a server string; the next server-side value crashes or blanks the screen.
   - GOOD: an explicit unknown case with a designed rendering.
   - `grep -rniE "enum |sealed class|as const|Literal\[" src/ app/ lib/` — for each enum decoded from the wire, find the fallback.
4. **Min-version gate with no store link.**
   - BAD: a blocking "please update" screen with no way to reach the store.
   - GOOD: the screen opens the store listing for the running platform.
   - `grep -rniE "minSupportedVersion|forceUpdate|requiredVersion|updateRequired" src/ app/ lib/` — then confirm a store-open call in the same screen.
5. **Removal proposed with no measurement.**
   - BAD: a server change deleting or renaming a field, with no installed-version figure and no date in the PR or ADR.
   - GOOD: the measured share and the accepted cutoff are recorded before the change lands.
   - Read the change description; absence of a number is the finding.
6. **Risky feature with no server-side switch.**
   - BAD: a new payment / sync / native path that can only be disabled by a store release.
   - GOOD: a flag, read at launch and foreground, defaulting to off when unreachable.
   - `grep -rniE "remoteConfig|featureFlag|isEnabled\(|launchDarkly|configValue" src/ app/ lib/`
7. **Client asserting more of the response than it renders.**
   - BAD: schema validation on fields the screen never displays; the app rejects a response it could have used.
   - GOOD: validate what you render, ignore the rest.
   - Review the validation layer against the render layer for each screen.

## Closure verbs

- **Attach** the client version to every request from one place.
- **Widen** the response additively instead of changing a field in place.
- **Loosen** the decoder to ignore unknown fields and tolerate missing optionals.
- **Default** every wire-decoded enum to an unknown case with a designed rendering.
- **Gate** a minimum supported version with a store escape hatch, never without.
- **Flag** every risky feature behind a server switch that fails safe.
- **Measure** the installed-version distribution before any removal.
- **Retire** an old shape only after the gate has been enforced for a full release cycle.

## Anti-patterns

- **"The app has been updated"** — said about a client with an unknown installed-version distribution. This is the sentence that precedes most mobile outages caused by a server deploy.
- **Version-number theatre** — `/v2` shipped for an additive change, then `/v3`, none retired, all maintained.
- **Coordinated release as a compatibility strategy** — coordination gets the new client *published*; it does not get it *installed*.
- **A strict decoder in the shared model layer** — turns every future additive server change into a client-side incident.
- **A forced-update screen with no store link** — the worst outcome this pattern can produce, and it ships more often than it should.
- **A kill switch that fails open** — a flag that defaults to enabled when config cannot be fetched is not a kill switch.
- **Tightening validation "to be safe"** — the old client sends what used to be valid and now gets an error it cannot interpret.
- **Removing an endpoint because usage looks like zero in the last 24 hours** — mobile usage is bursty and time-zoned; measure over a release cycle, not a day.

## Boundary

This pattern owns the **compatibility discipline between a server and clients that cannot be redeployed**: what may change, how clients tolerate change, how a minimum version is gated, and how anything is ever removed.

It does not own: general API design, envelope shape, error-contract uniformity, or pagination style (`backend` pack — this pattern constrains *when* those may change, not *what* they should be); the mechanism for delivering a client fix without a store release (`ota-updates`); retry, backoff, and queue behaviour (`offline-sync`); auth token storage (`native-storage`); the store review outcome (`@app-store-reviewer`).

Both packs are expected to cite this pattern. The reason it is a pattern rather than an agent: the discipline binds the **server** team, and an agent scoped to the mobile repository cannot enforce a rule about code it cannot see.

## Related

- `ota-updates.md` — owns the JS-layer delivery mechanism and its native boundary; this pattern owns the policy about who must update and when.
- `offline-sync.md` — a queued mutation written by an old client lands on a newer server; the additive rule is what makes that survivable.
- `app-lifecycle.md` — the launch-and-foreground hook where the version gate and remote flags are read.
- `release-pipeline.md` — the release cadence that determines how quickly a gate can actually be enforced.
- `@mobile-architect` — owns the client-side contract layer; invoke it when the networking layer needs restructuring rather than tightening.
- cross-pack `backend` — owns API design; this pattern is the constraint it must design within when a mobile client exists.

## Sources

- Apple, [App Review](https://developer.apple.com/distribute/app-review/) — "On average, 90% of submissions are reviewed in less than 24 hours", quoted here as the *fastest* link in the update chain, not as an adoption figure.

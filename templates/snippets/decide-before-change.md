---
purpose: The decision every improvement goes through before any code — performance, refactor, scale, database, architecture, a new technology. The measured problem, where the cost really is, two or three options with leaving it as one, cost against gain, what it delays, the risks, and a recommendation the person approves.
---

# Decide before you change — evidence, options, then the person's OK

An improvement is a choice, not a fix with one answer. The first solution that comes to mind is
not the decision, and a sophisticated option is not better for being sophisticated. **No measured
problem, no change:** without a number, the recommendation is to measure first, with the probe that
will.

Used by:
- every request to improve performance, refactor, scale, change the database, redesign the
  architecture or bring in a new technology, whether or not a command is running
  (`think-simplify-surgical.md` § 1), each time § 1 below says a card is required;
- `/optimize` (foundation moves, and what its scan finds that adds a moving part), `/audit` (rows
  § 1 gates), `/upgrade-dep` (a major or the runtime), `/scaffold-project` (the stack);
- the stop lines of `/perf-fix`, `/db-fix`, `/optimize-query`, `/ds-fix` and `/infra-fix`, and
  `/design-system` before it draws (each when its pack is installed);
- `@architect`, when a design needs something the project does not run today, and `/fix-bug`, when
  a fix does;
- `/polish`, before a first token scale, envelope or naming convention;
- every halt for a primitive the code lacks: § 10 names the command that builds it;
- `study-before-build.md` § 6: the brief of an improvement task carries its card;
- `review-action-plan.md` rule 7: a read-only report marks such a remedy `Decide first:`.

## 1. When a card is required
Before any code, when the change:
- **adds a moving part** the project does not run today: a dependency, a service, a store, a cache,
  a queue, a scheduled job, a new layer or pattern;
- **changes data at scale:** an index or a migration on a populated table, denormalisation, a
  materialised view, partitioning. A table is populated when it existed before the last release;
  when that cannot be read, treat it as populated;
- **moves responsibilities** across modules, or splits or merges modules;
- **raises capacity or running cost:** replicas, instance size, pool sizes, a paid service;
- **takes a major upgrade** of a library, a framework or the runtime;
- **has more than one reasonable shape:** options that differ in moving parts, cost, risk or undo,
  when the ask was to improve, speed up, scale, clean up or optimise. Two code layouts inside one
  closure verb are not two shapes.

Not required:
- **A security, data-loss or correctness defect** with one root fix and no new moving part. When
  its fix does add a moving part, the card still comes, with the options for *how*, and without
  option 0 (§ 4).
- **A mechanical, behaviour-preserving move from a closed verb list:** a `/refactor` verb
  (`move-to-module` moves one symbol, not a module's responsibility), a rename, dead code removed, a
  duplicate merged into its named canonical copy.
- **A fix whose root primitive the finding's class already fixes** (the `/perf-fix` table) and that
  adds no moving part.
- **An index with a measured `WORTH IT` verdict** (`/optimize-query`, from
  `ai/patterns/indexing-strategy.md`): the verdict is its cost-benefit, on measured inputs. Applying
  it to a populated table still stops where the applying command stops (`/db-fix`).

## 2. The problem, measured
- **The number and its source:** a profile, a log, a metric, a query plan, a test, an incident, a
  bill. Cite it: the `file:line`, the command and its output, the dashboard.
- **The target it misses:** the budget, the SLO, or the goal the person stated. A number already
  inside its target is not a problem today.
- **The cause,** not the symptom: why the number is what it is. A cause that is not shown is written
  `GUESS:`.
- **No number:** the recommendation is "measure first", naming the probe, and nothing else is built.
  A business need the person states ("customers wait at checkout") counts as the problem; its size
  is then measured before the options are priced.

## 3. Where the cost is — the biggest first
List the top contributors to the measured problem with each one's share, the way `/profile-perf`'s
contribution table does ("the order-items query: 400 ms of 4.6 s"). Work on the biggest first. A
contributor with a small share is not optimised before the bigger ones, however easy it is.

## 4. The options — two or three, leaving it among them
**Option 0 is leaving it:** what happens if nothing changes — the number today, and at the growth
the project expects (`ai/project-goals.md`, `ai/roadmap.md`, or the person's own figure). Then one
or two real options, the simplest that could work first (an existing primitive, an index, a
setting), then the bigger one.

**Option 0 is dropped only when there is nothing to leave:** a security, data-loss or correctness
defect (a scale-blocker that corrupts or loses data under load is one), a new project, or the how
of a feature the person already approved. A performance or capacity finding keeps it, even when it
is MUST FIX, and so does any other scale-blocker at a target the project has not reached yet.

For each option:
- **Cost:** the effort in hours or days; what it adds to run and watch; what it costs a month when
  it adds infrastructure or a paid service; the migration or cutover it needs; and building a
  primitive the project does not have yet (a cache client, a queue, a store), in the project's own
  shape.
- **Gain:** measured; or `ESTIMATED` with each term cited (calls × time per call × rate); or
  `unknown`, with the probe that would measure it. Never a guessed percentage.
- **Risks:** operational, security, scale, reliability and regression — only the ones that apply,
  one line each.
- **Undo:** can it be reverted in a day? A one-way door (a rewrite of stored data, a public
  contract, the first stored event) says so.
- **Return:** only when the cost and the gain share a unit (money a month, hours a week, time ×
  requests). Otherwise `return: not measurable — <why>`.

## 5. Impact against effort — one label per option
Impact is judged against the measured problem, not in general. Effort is low when the change stays
in one module, adds no moving part and takes days; it is high when it adds a moving part, migrates
data, or spans several modules.
- **Quick win:** closes the gap, or most of the biggest contributor, for low effort.
- **Major project:** closes the gap for high effort.
- **Fill-in:** low effort, small gain — a number already inside its target, or a small contributor.
- **Money pit:** high effort for a small or unknown gain. Never recommended.

## 6. What it delays
Name what waits while this is built: the next items of `ai/roadmap.md` or `/roadmap`'s
`ai/roadmap/plan.md`, the board's pick list, or the person's own list. A change that delays
something customers will see, for a gain they will not see, says so.

## 7. The recommendation
- **One option,** why in one line, and **when to revisit** it: the number or the date that would
  change the decision.
- **On a tie, the simpler option wins.** Leaving it wins a tie with anything that adds a moving
  part.
- **Never a technology for being popular, newer, or "what big companies do".**

## 8. The card and the approval
Written in the person's language, plain:

```
Decision:      <key> — <title>
Problem:       <the number, its source, the target it misses>  |  unmeasured — first: <probe>
Cause:         <the cause, shown>
Biggest costs: <the top contributors and their share>
Options:
  0. Leave it — <the number now, and at the expected growth>
  1. <option> — cost <effort · new parts · a month> · gain <measured | estimated (terms) | unknown>
     · risk <…> · undo <yes | one-way> · <label>
  2. <option> — …
Delays:        <what waits>
Recommend:     <option> — <why> · revisit when <trigger>
```

A small decision keeps `Decision` (its key), `Problem`, `Options` and `Recommend`.

**The key is the same in every run and every command:** `<change>:<target>`, the kind of change
and what it touches (a path, a module, a table and its columns, a package and its version, a
route). For example: `add-index:order_items(order_id)`, `split-module:src/orders`,
`upgrade:react@19`, `add-cache:GET /orders`. A study writing a brief computes the same key the
routed command will. A pick is matched to its card by the key, never by a run's own number
(`F-A-001`, `P-07`, which a later run renumbers) and never by the title. A card that names the same
change on the same target under a differently spelled key is the same card, and the report says
which key it matched.

- **A direct run** prints the card and waits for the person to pick an option. A sweep shows its
  cards in at most two rounds — before its first edit, and at the end for what its scan found —
  each answered in one reply.
- **Under `/task`,** the brief's card is approved with the brief (`study-before-build.md` § 6). The
  routed command reads the brief in the record folder (`record=`) before raising a card: a card with
  the same key is already picked, and is built without asking again.
- **A dispatched run decides nothing new:** `drain=1`, or any `brief=approved` dispatch. A card the
  command raises there (from its diagnosis, a vendor guide or a design) is held out, together with
  the work that pick would change: what depends on it, and the tactical work in the modules a
  carded foundation would move. Picks already made, in the store or the brief, are built. The
  command finishes everything else and returns `NEEDS_INPUT` with the new cards.
  `/task` asks the person in the session when one is there, and otherwise parks the card (`/task`
  § Parking); the pick resumes it.
- **`--yes`** accepts the recommendation only when it adds no moving part and is not one-way.
  Otherwise the card waits.
- **A pick that needs a primitive the project does not have** (a cache client, a queue, a store)
  builds it as part of the option: the card already priced it, and the person picked it. It is
  built in the project's own shape, with its ADR, and declared in the same commit (§ 10); refine
  is not what builds the pick.
- **A plan file** (`--plan`, `--plan-only`) never puts an unpicked card's change, or the work it
  holds (what depends on it, the tactical work in the modules it would move), under `## Steps` or
  `## Outputs`. A card answered before the plan is written becomes Steps and Outputs, and its
  pick is written to the command's store, beside the writes `plan-flag.md` step 1 and the
  command's own plan contract allow. An unanswered one is a
  `## Known unknowns` row reading `Decide first:` with the card. `/execute-plan` reports it as open
  and never resolves it.
- **Leave it chosen, or every option declined:** nothing is built. The card is kept with the
  decision.

## 9. Where it is kept, and the check after
- **The store, per command:**
  - `/add-feature` and `/fix-bug`: `ai/runs/<run-id>/decision.md`, written by the command with the
    person's pick. Under `/task` the pick is written to `brief.md`; on `--resume` the command copies
    `brief.md` from `record=` again and moves its picks into `decision.md` before the step that
    raised the card.
  - `/optimize`: `ai/optimize/decisions.md`.
  - `/audit`: `ai/audit/decisions.md`.
  - `/upgrade-dep`, `/optimize-query` and `/polish`: `ai/dynamic/decisions-pending.md`, one entry per card in
    that file's format. Its title carries the card's key, `Source:` names the command and the
    target, the options go under `Alternatives considered:`, the pick under `Decision:`, and the
    revisit trigger under `Status:` as `WATCHING — revisit when <trigger>`. A card with no pick
    yet reads `Decision: none yet` and `Status: AWAITING PICK — <date>`; only an entry with a real
    `Decision:` counts as picked, never its recommendation. `--dry-run` writes nothing.
  - `/design-system`: its design doc, `specs/<YYYYMMDD>-<slug>.md`.
  - A fixer (`/perf-fix`, `/db-fix`, `/ds-fix`, `/infra-fix`): `ai/dynamic/decisions-pending.md`
    too, keyed the same way, since the next audit renumbers its findings. The finding's
    closure-table row cites it (`decision: <key> → <pick>`). A pick given in the session is built in
    that run; a finding still waiting stays `awaiting decision`, and the next run on any report
    builds the pick it finds there by key.
- **Read before asking.** Before raising a card, a command reads every store by key: its own,
  `ai/dynamic/decisions-pending.md`, `ai/optimize/decisions.md` and `ai/audit/decisions.md` when
  they exist, and under `/task` the brief in the record folder. A decision already made in any of
  them, built or left as is, is not asked again unless its revisit trigger fired.
- **Commit the store by name:** with the run's other commits, or alone as
  `chore(decision): <key>` when the run commits nothing else (a plan run included: it is that
  run's only commit), so the next run starts on a clean tree.
- **In the record:** the chosen card goes into the feature record's `design.md`, under why this
  shape (`study-before-build.md` § 9), when the run has one; otherwise into the command's own
  report.
- **As an ADR** (`ai/decisions/`), when the choice adds a moving part, moves responsibilities across
  modules, or is one-way. The card's options become `## Alternatives considered`, option 0
  included. Its revisit trigger becomes `## Review triggers`.
- **After the build,** the same probe runs again, and the result is written beside the card:
  `after: <number>`. A gain that did not appear is reported, never dropped.

## 10. A primitive the code lacks — where it goes
`/setup-project --refine` re-reads the code and declares what is already there; it never writes
code. It extracts an idiom when three or more places depend on it, or when `ai/declared-idioms.md`
lists it, and it reads tokens and API and schema conventions from where the project defines them
(`phase-2-profile.md` § Foundations). So a halt for "the fix needs a primitive no oracle names"
asks one question first: is it in the code?
- **In the code, not declared** → `/setup-project --refine` declares it. A unit with fewer than
  three users is listed in `ai/declared-idioms.md` first, so refine extracts it.
- **Not in the code** → the command that builds that kind, never refine:
  - **a token or token scale, an API envelope or error contract, a missing UI state, an API or
    schema naming convention** → `/polish`, whose foundation step (step 4.5) introduces it before
    the fixes that use it;
  - **the one shared wrapper for tables, forms, headers, tabs, filters or buttons, or the
    validation pipeline** → `/unify-surfaces`, which extracts it from the instances already there;
    any other shared component → `/add-component` (frontend pack);
  - **a shared helper, hook or service** (a constants module, an error handler, a locale factory)
    → `/refactor`, which extracts it once the code has three copies (its Rule of Three); a feature
    that needs it → `/add-feature`. With fewer copies and no feature, no helper is built: the row
    stays halted with `below THR-DRY — <n> copies` as its reason, for the person to park or
    archive (in an align ledger, `parked`, or `archived-deprecated` with its ADR);
  - **a cache, a queue, a client, a store or another moving part** → `/optimize`, or the pack
    fixer after its audit (`/perf-audit` then `/perf-fix`, `/ds-audit` then `/ds-fix`,
    `/infra-audit` then `/infra-fix`), or `/add-feature`;
  - **a gate, a validator or a sanitiser** for a security finding → `/security-audit` then
    `/security-fix`, which owns the class; a permission or ability a feature needs →
    `/add-feature`.
- **A card first** (§ 1) when the new primitive adds a moving part or has more than one reasonable
  shape. A first token scale, a first envelope or error contract, and a rename across populated
  tables each have more than one. `/polish` keeps its cards in `ai/dynamic/decisions-pending.md`
  (§ 9).
- **Declared in the same commit** by the command that built it. The unit goes into
  `.claude/_extracted-idioms.md` in its section, its line ending `[declared: ai/declared-idioms.md]`,
  so the next reader finds it now. A row goes into `ai/declared-idioms.md`, so the next
  `/setup-project` run keeps it. A permission or ability is data in a file the oracle already
  names, not a unit: adding it needs no row. A convention `/polish`
  picks goes to `ai/api-conventions.md` or `ai/schema-conventions.md`, which no setup run writes.
- **The command that halted does not build it** inside its own run. An alignment phase never
  changes its oracle mid-phase (`check_oracle_unmodified`): the row is parked, the phase closes,
  the primitive is built and declared in its own commit, and the row is unparked and its phase run
  again from it (`/align-phase <N> --start-from=<id>`, on a fresh base). Any other halted row
  resumes on the next run.

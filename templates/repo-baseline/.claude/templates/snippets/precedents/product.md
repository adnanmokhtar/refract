# Precedents — Product (feature surface, tracking plan, plans and entitlements, launch readiness, requirement traceability)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **product** class: a shipped feature that is half-built (a call nobody serves, a link
to no page, a placeholder or mock rows on a reachable route, a control that does nothing), an
analytics event that drifts from its plan or fires before its outcome, a plan fact that two sources
state differently, a launch nobody can judge, and an acceptance criterion no test names. The oracles
that prove them are in [`proof-oracles.md`](../proof-oracles.md) § Product (V409–V429). The
detectors are `feature-surface-scan` (FS §1–§5, `surface-map.py`), `tracking-plan-scan`
(AN §1–§7, `event-inventory.py`), `entitlement-consistency-scan` (EN §1–§6), `launch-readiness`
(LR and the scorecard SC, `rules.json` + `readiness-score.py`) and `acceptance-criteria-check`
(TR §1–§4, the EARS lane and the spec-trace lane) (product pack). They are run by
`/audit-requirements --repo` and closed by `/product-fix`. Every BLOCKER and HIGH a run keeps goes
once to `@verifier` mode `refute`.

**Owned elsewhere.** A neighbour that sees the same site lists it as corroboration, deduped by
`file:line`; without the owner's pack the row is tagged `<class> (owner pack <x> not installed)` and
listed, never graded as product would grade its own. The splits:
- stale, dead, ownerless and unsafe-default flags and kill switches are devops `progressive-delivery`
  (§1–§9) and code-quality `dead-code-scan` §4; the scorecard reads them as PRR-FL-1 and PRR-PD-1;
- a page or component nothing mounts is code-quality `dead-code-scan`; partial CRUD and promised but
  unbuilt capability are `/roadmap`;
- copy completeness (hard-coded strings, missing keys, plurals, ICU) is frontend `i18n-scan`; FS §4
  reads catalogs only for placeholder *values*;
- error, empty, loading and permission states are ui-ux `ui-state-scan`; unknown-URL handling and
  click-navigation on non-links are frontend `routing-scan` §1/§4;
- PII in event properties and tracking before consent are security (`data-exposure-scan`,
  `@data-privacy-reviewer`); the server not enforcing what the UI hides, and limit-counter races, are
  security (`@api-security-reviewer`, `logic-race-scan`);
- money, rounding, proration and refunds are business `pricing-rule-scan`, tax and issued documents
  `tax-invoice-scan`; one flow's funnel drop-off
  and onboarding are business `/suggest-metrics --funnel`;
- SLO definitions, burn alerts, alert runbook links and readiness probes are observability
  (`slo-rule-scan`, `alert-rule-lint`, `metric-hygiene-scan` §7); `ai/runtime/slos.md` has one
  writer, observability's `/slo-audit`;
- AC → task → test links inside a delivery run are repo-baseline `trace-matrix.py` (owner
  `@verifier`); spec drift of a generated OpenAPI client is backend `http-contract-scan` §10.

"Is the behaviour correct" belongs to the owner of the class; "is the feature finished, judgeable and
consistent with what was promised" is product's.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**, or Refuted where the entry says so, unless the
flip evidence is shown with a `file:line`, a config value, a ledger row or a recorded oracle run.
Numbers are stable: detectors cite `precedents/product.md § <n>`; the `PP-*` id beside each number
is the research catalog's and resolves to the same entry.

Index: the claim and the gates · feature surface § 1–9 · analytics § 10–17 · plans and entitlements
§ 18–22 · launch and scorecard § 23–30 · traceability § 31–35 · posting rules · rationalizations.

## The claim, restated

§ 1 of the protocol takes one of five shapes here. Every one names **both ends**: the reference and
its counterpart, or the counterpart's absence after a written search. A row with one end is not a
candidate.

> **FS.** **[the client call, link, form action, redirect, placeholder or control at file:line]**
> reaches **[the served route, page route or effect at file:line — or "none after the written
> search"]** on **[a reachable production surface, flag state read]**, so a user meets **[the 404, the
> not-found page, the fake rows, the no-op]**, proven by **[V409–V412]**.
>
> **AN.** **[the event call at file:line]** sends **[name, properties]** at **[the firing point:
> intent, before the confirming await, after commit]**, while **[the plan line, the codegen function,
> the success file's event — or "no plan"]** says **[the other name, key set or outcome]**, proven by
> **[V413–V417]**.
>
> **EN.** **[source A at file:line]** states **[plan × feature = value or key]** and **[source B at
> file:line]** states **[the other value, or no gate]**, after **[every global guard and the central
> plan map were read]**, proven by **[V418–V421]**.
>
> **LR / SC.** **[rule id]** for **[feature slug or the repo]** is **[FAIL / UNVERIFIED]** because
> **[the typed field, the owner's ledger line, the tool exit]** reads **[the value]**, proven by
> **[V422–V426]**.
>
> **TR.** **[criterion id at spec:line]** has **[no test naming it / a test citing an id no spec
> holds / an undefined Gherkin step / a non-EARS sentence]**, proven by **[V427–V429]**.

**Two parts, refuted separately.** Part A says *the join is real*: the route table resolved the
global prefix, the plan file is the plan, the catalog is the list the code treats as the list, the
criterion id is an id. Part A is refuted first, because a wrong normaliser produces hundreds of rows
(§ 9). Part B says *what a user, a dashboard or a decision meets*.

**The proof rule.** A join row is a candidate. Static two-ended facts (FS §1–§3, AN §1–§4, EN
§1–§4, TR §1–§2) pass gate 6 with both ends cited (**S**) or the class oracle red (**T** tool exit,
**U** unit test). Behaviour classes (FS §5, AN §5–§6, EN §5) need **U** or **L** (a live request or
browser visit). A scorecard rule is proven only by `readiness-score.py` reading its evidence (§ 29).
Without the proof the row is **Unconfirmed** with the oracle written out.

## Reading the seven gates for product

| Gate | Product |
|---|---|
| 1 Reachability | the surface ships: a route mounted under the real prefix, a page in the route table, a component a mounted page renders, an event call on a path users take, a gate on a served handler. A flag off in every environment fails here (§ 4) |
| 2 Trigger | a real user meets it: clicks the link, submits the form, buys, upgrades, opens the dialog twice. For LR/SC: the launch or the stage change is actually planned |
| 3 Version | framework routing and SDK behaviour from the lockfile (React Router, Next, Nest versioning, the analytics SDK's dedupe); `UNREAD` without a lockfile |
| 4 Existing control | **the project's own control first** (§ 7): a route-parity test, typed routes, an OpenAPI-generated client under `tsc`, a typed event union or codegen plan, a catalog-typed gate key. Then proxies (§ 2), global guards (§ 18), a second delivery leg (§ 11) |
| 5 Impact | a user meets a dead end or fake data; a dashboard counts the wrong thing; a plan grants or denies what was sold; a launch decision has nothing to read. Hygiene with none of these is Hardening (§ 36) |
| 6 Proof | the two-ended S fact, a tool exit (T), a unit test with a fake sink or a catalog matrix (U), a live request or visit (L). An agent's reading alone never passes a behaviour class |
| 7 Environment | the build and the environment the surface ships in: a demo build (§ 5), a dev-only proxy (§ 2), test vs live billing ids (§ 21), the lifecycle stage of the feature (§ 25) |

## Feature surface

1. **PP-FS-1 Externally consumed routes have no in-repo caller.** Webhooks, OAuth callbacks, health and metrics, a public or partner API (spec-tagged public, a versioned external prefix), routes called by a mobile app or another service in the repo, cron-triggered HTTP and admin CLIs. FS §2 is Refuted for them. *Flips back:* the route is none of these and the reasons file does not list it.
2. **PP-FS-2 A proxied path is served.** A client path served by Next `rewrites`, a BFF, nginx/Caddy or a gateway config is not FS §1. Vite `server.proxy` is dev-only and serves nothing in production. *Flips back:* the production proxy config lacks the path.
3. **PP-FS-3 A no-op handler beside a real one.** A dialog's `onSubmit={() => undefined}` where the footer button performs the action is deliberate (seen on a real NestJS + React monorepo, commented in place, 2026-10-19). *Flips back:* no sibling control has an observable effect.
4. **PP-FS-4 Placeholders out of reach.** "Coming soon" in a doc comment (the only copy-lane hit on that monorepo was a JSDoc line), behind a flag off in every environment (read the flag config rows, devops `progressive-delivery`), in Storybook stories or `*.test-data.*`, or a deliberate waitlist teaser. The `placeholder=` input attribute is not placeholder UI. *Flips back:* reachable on a production route with the flag on in any environment.
5. **PP-FS-5 Demo builds.** MSW handlers, fixtures and faker data in a declared demo build (`VITE_DEMO=1`, a `demo` target) are intended when the production bundle excludes them. *Flips back:* the mock module is in the production build output, or `worker.start()` is not gated by `NODE_ENV` / `import.meta.env.DEV`.
6. **PP-FS-6 Pages reached from outside the app.** Landing pages from email, ads and QR codes, and deep links declared in `sitemap.xml`, `apple-app-site-association` or `assetlinks.json`, have no in-app link by design. A page nothing mounts is code-quality's (`dead-code-scan`); knip never reports dead pages because route files are plugin entries.
7. **PP-FS-7 The project's own control decides the class.** When a two-sided route-parity test exists (an every-call-names-a-served-route test and its reverse), run it: it is the tier-U oracle, and FS §1/§2 print `controlled (<test>)`. On the measured monorepo that test's header recorded 2 unserved calls on its first run, one of which failed open. Report only what the control does not cover (links, form actions, placeholders). *Flips back:* the control is skipped in CI, or its allow-list carries the path without a reason.
8. **PP-FS-8 Links handled by the server** (`/logout`, `/auth/callback`, a file download the API serves) are API routes, not page routes; FS §3 resolves them against the served-route table.
9. **PP-FS-9 Prefix sanity.** When more than half of the client calls are unserved **and** more than half of the served routes are uncalled, the normaliser is wrong (a missing global prefix, a version segment, a wrapper's base URL), and no FS §1/§2 row is a candidate until the join is fixed. On the measured monorepo the raw greps returned 819 client calls and 1,318 route declarations: a per-line grep cannot decide the join.

## Analytics

10. **PP-AN-1 Auto-tracked and non-track calls are not plan events.** Page and screen views, autocapture, `identify` / `group` / `page`, and vendor lifecycle events. Filter a multi-source plan by source before AN §2.
11. **PP-AN-2 A second delivery leg.** A client pixel absent when the user is signed in, while a server conversion leg still delivers the event, is not AN §2 (measured monorepo). *Flips back:* no leg delivers the event in that context.
12. **PP-AN-3 Similar names, distinct events.** `StoreConnected` and `StoreConnectedFromOnboarding` are two events; legacy names frozen for dashboard continuity are declared drift. *Flips back:* the same trigger and the same properties under two spellings.
13. **PP-AN-4 Hashing before the vendor.** Raw email or phone sent to the own server and hashed before the vendor call is not a PII leak (`sha256(email)` for ad matching). The PII class is security's either way. *Flips back:* the raw value reaches a third party.
14. **PP-AN-5 Intent events fire on intent.** `…Started`, `…Clicked`, `…Viewed` on a click are correct. AN §5 is only an *outcome* name (`Purchased`, `Completed`, `Registered`, `Subscribed`) fired before the confirming response, or in both the success and the failure branch. A purchase event fired when the checkout URL is created, before payment, is the class (a measured candidate on the monorepo, unverified there: it counts checkout starts as purchases unless a server-side confirmed-purchase event exists).
15. **PP-AN-6 Per-open impressions repeat.** An impression that fires once per open repeats legitimately across opens. A wrapper kept stable by a ref after a double count is the control. *Flips back:* it fires more than once per open.
16. **PP-AN-7 No plan, no plan-diff.** Without a plan (codegen plan, vendor export, typed union, plan document), AN §1, §2 and §4 print `N/A (no plan — no oracle)`; only the inventory row (Hardening: "no plan: n events, k names"), AN §3, §5, §6 and §7 run. A plan-file glob as wide as `**/events*` matches domain-event specs: use the narrowed names (`tracking-plan`, `ampli.json`, `avo.json`, Iglu schemas).
17. **PP-AN-8 A name built at runtime is unresolved, never a mismatch.** The same holds for flag keys and gate keys built from variables. Print `unresolved (k sites)` in the coverage block; a vendor CLI that needs a login is `NOT-RUN (auth)`, never PASS.

## Plans and entitlements

18. **PP-EN-1 Split guards.** Two global guards, each judging one key family and returning `true` for the other's keys (coarse module keys vs extension slugs on the measured monorepo), gate every handler between them. A join of "gate key not in the coarse catalog" reported 22 handlers as ungated that were gated. EN §2 is a candidate only after every `APP_GUARD` / middleware / policy registry is read and what each admits is written down. *Flips back:* a key neither guard recognizes.
19. **PP-EN-2 The central plan map is the entitlement layer.** Plan literals inside it are the catalog; only a plan literal in a feature check outside it is EN §3. Plan names in migrations, seeds and analytics labels are not checks.
20. **PP-EN-3 Grandfathered and fair-use limits.** A legacy plan, and "unlimited" with a documented fair-use cap, differ from current copy by design. *Flips back:* no grandfathering record and no fair-use statement.
21. **PP-EN-4 Billing ids in seeds and tests are fine.** Only runtime source counts for EN §6; test-mode and live-mode ids differ, so a literal is wrong in one of them. A live check needs a test key: `NOT-RUN (auth)`.
22. **PP-EN-5 Marketing copy is read for numbers only.** Limits, seats and prices are compared; prose is never parsed for meaning, and a rounded marketing number ("10k") matches its exact value.

## Launch and scorecard

23. **PP-LR-1 External-only rules are UNVERIFIED, never FAIL and never PASS.** On-call staffed, a restore tested, a rollback drill held, load-test results, branch protection: `UNVERIFIED (needs <system>)`. A file that names them is a claim, not the result.
24. **PP-LR-2 Non-applicable rules stay in the table** as `N/A (<reason>)`. A rule deleted from the table, or N/A with no reason, reads as "looked, passed" and is a defect in the run.
25. **PP-LR-3 The target follows the stage.** Experiment and beta are graded against bronze, GA against silver; gold is opted into (`--target=gold`). A beta that fails a gold rule is not NOT-READY.
26. **PP-LR-4 Kill switches and permission flags are permanent.** Never age-graded as stale; devops owns them, and the scorecard does not count them twice.
27. **PP-LR-5 A template is not a record.** A success file, rollback record or runbook whose field still holds `<…>`, `TBD`, `TODO`, `???` or the template's sample text is FAIL, not PASS. Fields are typed: a date in the future, a named person (not a team handle), a number with a unit.
28. **PP-LR-6 Levels are cumulative gates, never a weighted sum.** Silver means every bronze and every silver rule passes. A weight would let ten passing rules hide one failing kill switch.
29. **PP-LR-7 A ledger row is evidence only when its report exists and is fresh.** A `ledger` evidence row that cites an audit report which is not on disk, or one older than the run's window, is UNVERIFIED; the scorecard never re-greps the owner's class.
30. **PP-LR-8 A tool that did not run is NOT-RUN.** A tool lane's PASS needs the command and its exit code recorded in this run; a missing binary or a refused login is `NOT-RUN (<reason>)`.

## Traceability

31. **PP-TR-1 An id in a test title or comment is a link, not proof.** Read the assertion before a criterion counts as tested; `trace-matrix.py` has the same honest limit (a substring check).
32. **PP-TR-2 Tagged-out features make steps look unused.** A step definition used only by a `@wip` or `@manual` scenario is not dead glue. *Flips back:* no feature file uses it under any tag.
33. **PP-TR-3 Bounded adjectives are bounded.** "Fast (p95 under 300 ms server-side at 500 rps)" passes; the vague-word list flags only words with no bound beside them.
34. **PP-TR-4 EARS lint reads the run-ledger format only.** `ears-lint.py` reads `### REQ-###` stories with `- AC-###:` lines. A prose spec is reviewed by the four manual tests; a lint exit on a file in another format is not evidence.
35. **PP-TR-5 Ids from an external tracker.** A test citing `PROJ-123` that no spec in the repo holds is resolved by its prefix against the tracker, not reported as TR §2. *Flips back:* the prefix is the spec's own.

## Posting rules (product)

36. Hygiene with no user, dashboard or decision impact is **Hardening**: an untyped event channel (AN §7), an uncalled read-only route (FS §2), a scorecard gap above the target level. NITs are capped at 5 per report, each with its site.
37. Every FS, AN and EN row carries both ends; every LR/SC row carries the rule id, the evidence token (Run / Static / UNVERIFIED / N/A) and its source; every TR row carries the criterion id and its spec line.
38. One root cause at N sites is one finding with N sites: a wrapper's base URL missing the prefix, a plan map that omits a tier, a tracking wrapper with `name: string`.

## Rationalizations to reject (product)

**Wrongly accepting "finished":**
- "The button typechecks and every mocked test passes." A mock serves the route nobody serves.
- "The event was added." Added is not arriving: run the query, or the rule is UNVERIFIED.
- "There is a runbook." Open it; a template is FAIL (§ 27).
- "The launch checklist is all green." Which rules ran this session, and which were read from a file's existence (§ 23, § 29)?
- "The agent traced every requirement." Inferred links over-link and trail plain retrieval baselines; only id-anchored links count (§ 31).

**Wrongly flagging a defect:**
- "This route has no caller." Webhook, callback, public API, another service (§ 1)?
- "This handler is ungated." Read every global guard first (§ 18).
- "800 unserved calls." That is a normaliser failure (§ 9), not 800 findings.
- "The event name differs." Two events by design (§ 12), or an intent event (§ 14)?
- "The beta fails gold." Grade it against its stage (§ 25).

---

Sources: the product research catalog (2026-10-19) § 1–5 and its two notes (tools and taxonomy;
launch readiness, PRR, traceability and LLM evidence). Scorecard levelling follows the published
level models of OpsLevel rubrics (docs 2025-12-11), Cortex, Port and Spotify Soundcheck (cumulative
levels), against Atlassian Compass's weighted percentage; N/A-with-reason and stage targets follow
GitLab's readiness templates; Yes/No/N/A risk tagging follows the AWS Operational Readiness Reviews
whitepaper (2022-06-30). The cucumber-js dry-run exit behaviour is from its 13.3.0 docs (2026-10-05).
The LLM failure modes behind § 23, § 29 and § 31 are OverclaimBench (arXiv 2609.20812, 2026-09),
arXiv 2512.04864 and the trace-link-recovery results cited in the research (KIT 2025; arXiv
2602.01253). Real-repo rows were measured read-only on one NestJS + React monorepo on 2026-10-19.
Paraphrased; no text is reproduced beyond short quoted identifiers.

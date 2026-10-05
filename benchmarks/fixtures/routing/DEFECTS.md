# Labelled asks — `routing`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir; staging writes
`asks.txt` (case id + ask, no labels) and nothing else.

Fixture shape: 100 natural-language asks, each labelled with the one command `/do` must route it to and, for a build or change ask, the risk tier (§4.3) it must predict before any code exists.
Kind: routing
Invocation: /do --route-only "<ask>"

**What it measures.** `/do --route-only <ask>` routes exactly as `/do` would and prints one line —
`ROUTE /<command> <tier>` — where the tier is `T0`..`T3` for an ask that lands on a delivery command
(`/add-feature`, a leaf build command such as `/add-migration`, or `/fix-bug`) and `-` for everything
else (a level-D command prints the same line: it is still the route). Three numbers:

- **command accuracy** — answers whose command equals the key's, over all 100 cases;
- **tier accuracy** — answers whose tier equals the key's, over the cases whose key tier is not `-`;
- **under-tiered T3** — cases keyed T3 that the answer put lower (or gave no tier). The Phase-4
  proving gate is ≥ 90% command accuracy, ≥ 85% tier accuracy and **0** under-tiered T3 cases.

**How the labels were made (answer key first).** Every tier follows the proposal's §4.3 table
literally — the definitions are copied below — and when two signals fire the highest tier wins.
The key was written from §4.3, `templates/governance/tiers.json` and `commands/do.md` before any
scoring code existed and without reading the deterministic classifier
(`templates/repo-baseline/.claude/scripts/risk-tier.py`) it is later measured against. `trigger:`
names the T3 trigger(s) from `tiers.json` → `t3_triggers` that make a case T3 (`score.py --verify`
checks that every trigger is covered at least once).

| Tier | §4.3 definition (any matching signal; highest wins) |
|---|---|
| T0 | docs, copy, config with no runtime effect, typo; no behaviour change |
| T1 | one module, mirrors a sibling; no new endpoint, write path, external call, dependency, auth, PII or money |
| T2 | new endpoint, write path, external call, new UI surface, new dependency, cross-module |
| T3 | auth, authz, roles; money movement; PII; tenant isolation; migration on a populated table; infra/CI; crypto; breaking public API; new dependency on a write path; blast radius above threshold |

**Routing conventions the key assumes** (the Phase-4 design of `/do`): every ask to build or change a
feature routes to `/add-feature` — the cross-stack delivery orchestrator; the stack packs'
`add-feature` files are its lane presets — including an endpoint, page or component ask; docs, copy
and typo changes also route to `/add-feature`, tier `T0` (a direct edit plus checks, no run
directory); a report of broken behaviour routes to `/fix-bug`, tiered by what the fix touches; an ask
that names a migration explicitly keeps the `"add migration"` row → `/add-migration`. Every other
command is the `do.md` row that matches.

`decoy:` marks a deliberately hard case — the surface wording points one way and the rule points the
other (a button ask that is copy-only, a refund with no money word, an auth word in a docs ask, a
negation). `score.py` reports decoy accuracy separately.

## Build and change asks — T3

```route
id:      RT-001
ask:     add a refund button to the order details page
command: /add-feature
tier:    T3
trigger: money-movement
why:     §4.3 T3 "money movement" — a refund moves money back to the customer; do.md row "add + UI noun" → /add-feature
```

```route
id:      RT-002
ask:     let support give customers their money back when an order arrives damaged
command: /add-feature
tier:    T3
trigger: money-movement
why:     §4.3 T3 "money movement" — giving money back is a refund, whatever the wording
```

```route
id:      RT-003
ask:     add a way for support to reverse a completed purchase from the order screen
command: /add-feature
tier:    T3
trigger: money-movement
decoy:   refund with no money word
why:     §4.3 T3 "money movement" — reversing a completed purchase returns the payment; no money word appears
```

```route
id:      RT-004
ask:     let customers tip their driver at checkout
command: /add-feature
tier:    T3
trigger: money-movement
why:     §4.3 T3 "money movement" — a tip is an additional charge
```

```route
id:      RT-005
ask:     charge a late fee when an invoice is more than 30 days overdue
command: /add-feature
tier:    T3
trigger: money-movement
why:     §4.3 T3 "money movement" — a new automatic charge
```

```route
id:      RT-006
ask:     let customers top up their wallet with a card and spend the balance on orders
command: /add-feature
tier:    T3
trigger: money-movement
why:     §4.3 T3 "money movement" — card top-up and balance spend move money
```

```route
id:      RT-007
ask:     let admins see everyone's invoices
command: /add-feature
tier:    T3
trigger: auth-roles
why:     §4.3 T3 "authz, roles" — widens what a role may read across users; invoices are billing data
```

```route
id:      RT-008
ask:     add a read-only viewer role that can open projects but not edit them
command: /add-feature
tier:    T3
trigger: auth-roles
why:     §4.3 T3 "roles" — a new role and its permission checks
```

```route
id:      RT-009
ask:     add sign in with Google
command: /add-feature
tier:    T3
trigger: auth-roles
why:     §4.3 T3 "auth" — a new authentication path (also an external call; highest wins)
```

```route
id:      RT-010
ask:     lock an account for 15 minutes after five failed login attempts
command: /add-feature
tier:    T3
trigger: auth-roles
why:     §4.3 T3 "auth" — changes the login path
```

```route
id:      RT-011
ask:     show the customer's phone number and home address on the order page
command: /add-feature
tier:    T3
trigger: pii
decoy:   looks like a one-line display change
why:     §4.3 T3 "PII" — exposes phone and address on a new surface; without the PII it would be T1
```

```route
id:      RT-012
ask:     let users download everything we store about them as a zip file
command: /add-feature
tier:    T3
trigger: pii
why:     §4.3 T3 "PII" — a personal-data export
```

```route
id:      RT-013
ask:     export the newsletter subscribers' email addresses to CSV for marketing
command: /add-feature
tier:    T3
trigger: pii
why:     §4.3 T3 "PII" — bulk export of email addresses
```

```route
id:      RT-014
ask:     let a user belong to more than one workspace and switch between them from the top bar
command: /add-feature
tier:    T3
trigger: tenant-isolation, auth-roles
why:     §4.3 T3 "tenant isolation" — membership across tenants changes which tenant a request resolves to
```

```route
id:      RT-015
ask:     add an internal report that shows usage totals for every customer account side by side for the ops team
command: /add-feature
tier:    T3
trigger: tenant-isolation
why:     §4.3 T3 "tenant isolation" — one query deliberately reads across all tenants
```

```route
id:      RT-016
ask:     split the full_name column on the customers table into first_name and last_name
command: /add-feature
tier:    T3
trigger: migration-populated-table, pii
why:     §4.3 T3 "migration on a populated table" — rewrites an existing column with data (and the data is PII)
```

```route
id:      RT-017
ask:     write a migration that makes orders.status NOT NULL — the table has a few million rows
command: /add-migration
tier:    T3
trigger: migration-populated-table
why:     §4.3 T3 "migration on a populated table"; do.md row "add migration" → /add-migration
```

```route
id:      RT-018
ask:     add a /healthz endpoint and point the Kubernetes liveness and readiness probes at it
command: /add-feature
tier:    T3
trigger: infra-ci
why:     §4.3 T3 "infra/CI" — changes the deployment manifests (a new endpoint alone would be T2)
```

```route
id:      RT-019
ask:     serve product images through the CDN and add the cache rules to the CloudFront config in infra/
command: /add-feature
tier:    T3
trigger: infra-ci
why:     §4.3 T3 "infra" — edits infrastructure configuration
```

```route
id:      RT-020
ask:     encrypt customers' national ID numbers at rest
command: /add-feature
tier:    T3
trigger: crypto, pii
why:     §4.3 T3 "crypto" and "PII"
```

```route
id:      RT-021
ask:     sign our outgoing webhook payloads with an HMAC so partners can verify them
command: /add-feature
tier:    T3
trigger: crypto
why:     §4.3 T3 "crypto" — a signature scheme (the webhook itself is an external call, T2; highest wins)
```

```route
id:      RT-022
ask:     change the public orders API to return the total as an object with amount and currency instead of a plain number
command: /add-feature
tier:    T3
trigger: breaking-api
why:     §4.3 T3 "breaking public API" — an existing response field changes type for every client
```

```route
id:      RT-023
ask:     make the email field required on the public POST /customers API
command: /add-feature
tier:    T3
trigger: breaking-api, pii
why:     §4.3 T3 "breaking public API" — requests that were valid start failing
```

```route
id:      RT-024
ask:     use the sharp library to resize product photos when sellers upload them
command: /add-feature
tier:    T3
trigger: new-dependency-on-write-path
why:     §4.3 T3 "new dependency on a write path" — a new package runs inside the upload write
```

```route
id:      RT-025
ask:     make the shared API client retry failed requests three times — every module in the app goes through it
command: /add-feature
tier:    T3
trigger: blast-radius
why:     §4.3 T3 "blast radius above threshold" — the ask itself says every module depends on the changed file
```

```route
id:      RT-026
ask:     change the base Button component so every button in the app ignores a second click while its action is running
command: /add-feature
tier:    T3
trigger: blast-radius
why:     §4.3 T3 "blast radius above threshold" — the base component every screen imports
```

## Build and change asks — T2

```route
id:      RT-027
ask:     let users add notes to a project
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" + new UI; no T3 signal
```

```route
id:      RT-028
ask:     let users star their favourite projects and show starred ones first
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" — a persisted star
```

```route
id:      RT-029
ask:     add a GET /categories endpoint that returns the product categories
command: /add-feature
tier:    T2
why:     §4.3 T2 "new endpoint"; read-only, no T3 signal (build asks go to /add-feature in the Phase-4 router)
```

```route
id:      RT-030
ask:     add a page where users can see the searches they saved
command: /add-feature
tier:    T2
why:     §4.3 T2 "new UI surface"
```

```route
id:      RT-031
ask:     show the current weather for the delivery city on the dispatch screen using the OpenWeather API
command: /add-feature
tier:    T2
why:     §4.3 T2 "external call"
```

```route
id:      RT-032
ask:     add an archive button to projects so archived ones drop out of the main list
command: /add-feature
tier:    T2
decoy:   a button that is a real write path, not copy
why:     §4.3 T2 "write path" — archiving persists a state change
```

```route
id:      RT-033
ask:     add tags to products and let staff filter the catalogue by tag
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" + "cross-module" (catalogue + admin)
```

```route
id:      RT-034
ask:     let staff import the product catalogue from a CSV file
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" — bulk writes; products carry no PII or money movement
```

```route
id:      RT-035
ask:     add a notification preferences page where users pick which emails they get
command: /add-feature
tier:    T2
why:     §4.3 T2 "new UI surface" + "write path"
```

```route
id:      RT-036
ask:     call the shipping provider's webhook when an order is marked as packed
command: /add-feature
tier:    T2
why:     §4.3 T2 "external call"; no signing, no money
```

```route
id:      RT-037
ask:     add a comment thread to each task
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" + "new UI surface"
```

```route
id:      RT-038
ask:     let users drag the columns on the kanban board into a new order and keep it next time
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" — the order is persisted
```

```route
id:      RT-039
ask:     add a charting library and draw the weekly sales trend on the dashboard
command: /add-feature
tier:    T2
decoy:   money-adjacent word with no money movement; dependency on a read path
why:     §4.3 T2 "new dependency" on a read-only surface — reading sales figures moves no money
```

```route
id:      RT-040
ask:     add a search box to the help centre that queries Algolia
command: /add-feature
tier:    T2
why:     §4.3 T2 "external call" (+ new dependency on a read path)
```

```route
id:      RT-041
ask:     write a migration that adds a nullable notes column to the shipments table we created last week — it's still empty
command: /add-migration
tier:    T2
decoy:   a migration that is not on a populated table
why:     §4.3 — no T3 "migration on a populated table" (new, empty table, nullable column); a schema change → T2
```

```route
id:      RT-042
ask:     add a page listing every scheduled job with its last run time and result
command: /add-feature
tier:    T2
why:     §4.3 T2 "new UI surface"
```

```route
id:      RT-043
ask:     let project owners duplicate a project with all its tasks
command: /add-feature
tier:    T2
why:     §4.3 T2 "write path" — bulk copy of records within one tenant
```

## Build and change asks — T1

```route
id:      RT-044
ask:     add sorting by due date to the tasks list, the same way the projects list sorts
command: /add-feature
tier:    T1
why:     §4.3 T1 — one module, mirrors a sibling, read-only, no new endpoint
```

```route
id:      RT-045
ask:     show a loading spinner on the reports table while it fetches, like the projects table does
command: /add-feature
tier:    T1
why:     §4.3 T1 — one module, mirrors a sibling
```

```route
id:      RT-046
ask:     add a created-at column to the products table
command: /add-feature
tier:    T1
why:     §4.3 T1 — a display column from data the page already loads
```

```route
id:      RT-047
ask:     add a status filter to the shipments list like the one on the orders list
command: /add-feature
tier:    T1
why:     §4.3 T1 — mirrors a sibling filter, read-only
```

```route
id:      RT-048
ask:     show how many open tasks each project has next to its name
command: /add-feature
tier:    T1
why:     §4.3 T1 — read-only display in one module
```

```route
id:      RT-049
ask:     show the full product name in a tooltip when it gets cut off in the catalogue grid
command: /add-feature
tier:    T1
why:     §4.3 T1 — one component, no data or write change
```

```route
id:      RT-050
ask:     highlight overdue tasks in red on the task list
command: /add-feature
tier:    T1
why:     §4.3 T1 — presentation logic in one module
```

```route
id:      RT-051
ask:     add a copy-link button next to each project in the projects list
command: /add-feature
tier:    T1
decoy:   a button with behaviour (client-only), neither copy nor a write path
why:     §4.3 T1 — client-side clipboard action, no write path or endpoint
```

```route
id:      RT-052
ask:     group the activity feed by day
command: /add-feature
tier:    T1
why:     §4.3 T1 — read-only re-grouping in one module
```

```route
id:      RT-053
ask:     show the SKU under the product name on the product card
command: /add-feature
tier:    T1
why:     §4.3 T1 — display of a field already loaded
```

```route
id:      RT-054
ask:     add a client-side text filter to the customers list without touching the API or the database
command: /add-feature
tier:    T1
decoy:   negation — no API, no DB; the customers already listed are filtered, nothing new is exposed
why:     §4.3 T1 — one module, no endpoint, no write path, no new data shown
```

```route
id:      RT-055
ask:     make the slash key focus the search box on the projects page
command: /add-feature
tier:    T1
why:     §4.3 T1 — a keyboard shortcut in one page
```

## Build and change asks — T0

```route
id:      RT-056
ask:     fix the typo 'Recieve' on the notification settings page
command: /add-feature
tier:    T0
why:     §4.3 T0 "typo"; a typo routes to /add-feature as a direct edit (Phase-4 router), not /fix-bug
```

```route
id:      RT-057
ask:     change the Submit button on the feedback form to say Send feedback
command: /add-feature
tier:    T0
decoy:   a button ask that is copy-only
why:     §4.3 T0 "copy" — the label changes, the behaviour does not
```

```route
id:      RT-058
ask:     document how login works in the README
command: /add-feature
tier:    T0
decoy:   auth word in a docs-only ask
why:     §4.3 T0 "docs" — no code changes; the auth word describes the subject, not the change
```

```route
id:      RT-059
ask:     update the README with the new local setup steps
command: /add-feature
tier:    T0
why:     §4.3 T0 "docs"
```

```route
id:      RT-060
ask:     reword the empty-cart message so it sounds friendlier
command: /add-feature
tier:    T0
why:     §4.3 T0 "copy"
```

```route
id:      RT-061
ask:     fix the broken link to the authentication guide in the API docs
command: /add-feature
tier:    T0
decoy:   "fix" + "broken" + an auth word, yet docs-only
why:     §4.3 T0 "docs" — a docs link, no behaviour change
```

```route
id:      RT-062
ask:     add comments to the payment helpers explaining that amounts are stored in cents
command: /add-feature
tier:    T0
decoy:   money words in a comments-only change
why:     §4.3 T0 "docs" — comments only, no behaviour change
```

```route
id:      RT-063
ask:     rename the Refund button label to Return payment
command: /add-feature
tier:    T0
decoy:   money word on a copy-only button
why:     §4.3 T0 "copy" — the label changes, the refund flow does not
```

```route
id:      RT-064
ask:     update the copyright year in the footer to 2026
command: /add-feature
tier:    T0
why:     §4.3 T0 "copy"
```

```route
id:      RT-065
ask:     set YAML files to two-space indentation in .editorconfig
command: /add-feature
tier:    T0
why:     §4.3 T0 "config with no runtime effect"
```

## Bug reports

```route
id:      RT-066
ask:     the orders list crashes when a customer has no orders yet
command: /fix-bug
tier:    T1
why:     do.md row "crash" → /fix-bug; §4.3 T1 — read path in one module
```

```route
id:      RT-067
ask:     users from one company can open another company's invoices by changing the id in the URL
command: /fix-bug
tier:    T3
trigger: tenant-isolation
why:     do.md "broken" behaviour → /fix-bug; §4.3 T3 "tenant isolation"
```

```route
id:      RT-068
ask:     refunds go out twice when support double-clicks the button
command: /fix-bug
tier:    T3
trigger: money-movement
why:     /fix-bug; §4.3 T3 "money movement" — duplicate refunds
```

```route
id:      RT-069
ask:     after logging out the old session token still works
command: /fix-bug
tier:    T3
trigger: auth-roles
why:     /fix-bug; §4.3 T3 "auth"
```

```route
id:      RT-070
ask:     customers whose account currency is euros are being charged in dollars
command: /fix-bug
tier:    T3
trigger: money-movement
why:     /fix-bug; §4.3 T3 "money movement" — the charge itself is wrong
```

```route
id:      RT-071
ask:     users' phone numbers are showing up in the server logs
command: /fix-bug
tier:    T3
trigger: pii
why:     /fix-bug; §4.3 T3 "PII"
```

```route
id:      RT-072
ask:     saving a product with an empty description returns a 500
command: /fix-bug
tier:    T2
why:     /fix-bug; §4.3 T2 "write path"
```

```route
id:      RT-073
ask:     the nightly export to the warehouse partner's SFTP server fails without any error
command: /fix-bug
tier:    T2
why:     /fix-bug; §4.3 T2 "external call"
```

```route
id:      RT-074
ask:     the date picker on the reports page shows the wrong month in Safari
command: /fix-bug
tier:    T1
why:     /fix-bug; §4.3 T1 — one component, read-only
```

```route
id:      RT-075
ask:     the search results page goes blank when the query contains an apostrophe
command: /fix-bug
tier:    T1
why:     /fix-bug; §4.3 T1 — one module's read path
```

```route
id:      RT-076
ask:     the profile page spinner never stops when the API is slow
command: /fix-bug
tier:    T1
why:     /fix-bug; §4.3 T1 — a loading state in one page
```

## Non-build asks (no tier)

```route
id:      RT-077
ask:     are we ready for 10x traffic on checkout?
command: /audit
tier:    -
why:     do.md row "ready for traffic" → /audit
```

```route
id:      RT-078
ask:     audit the orders module for SOLID, performance and security
command: /audit
tier:    -
why:     do.md row "audit + multi-axis" → /audit
```

```route
id:      RT-079
ask:     our buttons ignore the spacing tokens on the auth pages
command: /align
tier:    -
decoy:   auth word + surface noun; the remedy applies an existing token
why:     do.md row "the buttons ignore our spacing tokens" + precedence worked case B → /align
```

```route
id:      RT-080
ask:     half the services call console.log directly and half use our logger helper — make them all use the helper
command: /align
tier:    -
why:     do.md row "some-X-some-Y" + already-named shared helper applied in place → /align
```

```route
id:      RT-081
ask:     our error shape is different on every endpoint
command: /polish
tier:    -
why:     do.md row "our error shape is different everywhere" → /polish
```

```route
id:      RT-082
ask:     the dashboard works but still feels unfinished
command: /polish
tier:    -
why:     do.md /polish row (finish that does not exist yet); /polish description example
```

```route
id:      RT-083
ask:     unify all the tables across the app
command: /unify-surfaces
tier:    -
why:     do.md row "unify all tables" → /unify-surfaces
```

```route
id:      RT-084
ask:     some pages use the shared PageHeader and some roll their own
command: /unify-surfaces
tier:    -
why:     do.md precedence worked case A → /unify-surfaces
```

```route
id:      RT-085
ask:     optimize the whole project
command: /optimize
tier:    -
why:     do.md row "optimize + whole-project" → /optimize
```

```route
id:      RT-086
ask:     extract the price formatting in src/orders/OrderRow.tsx into its own helper
command: /refactor
tier:    -
decoy:   money word on a behaviour-preserving extract
why:     do.md row "extract + specific file" → /refactor
```

```route
id:      RT-087
ask:     what's left before this is shippable?
command: /roadmap
tier:    -
why:     do.md row "what's left before this is shippable" → /roadmap
```

```route
id:      RT-088
ask:     map the missing features in the billing module so I can start building
command: /roadmap
tier:    -
decoy:   money-adjacent word in a read-only mapping ask
why:     do.md row "map the missing features" → /roadmap
```

```route
id:      RT-089
ask:     review the API for security holes — security only
command: /security-audit
tier:    -
why:     do.md row "review + security (security-only)" → /security-audit
```

```route
id:      RT-090
ask:     audit the product page for performance — why is it so slow?
command: /perf-audit
tier:    -
why:     do.md row "audit + perf / slow (perf-only)" → /perf-audit
```

```route
id:      RT-091
ask:     review my changes before I push
command: /review-changes
tier:    -
why:     do.md row "review my changes" → /review-changes
```

```route
id:      RT-092
ask:     grab the next ticket and start on it
command: /task
tier:    -
why:     do.md row "next ticket" → /task
```

```route
id:      RT-093
ask:     upgrade React to 19
command: /upgrade-dep
tier:    -
why:     do.md row "upgrade X to N" → /upgrade-dep
```

```route
id:      RT-094
ask:     deploy this branch to staging
command: /deploy-stage
tier:    -
why:     do.md row "deploy + environment" → /deploy-stage (level D: printed, still the route)
```

```route
id:      RT-095
ask:     roll back the last production deploy
command: /rollback-deploy
tier:    -
why:     do.md row "rollback" → /rollback-deploy (level D)
```

```route
id:      RT-096
ask:     is my setup stale?
command: /setup-project-health
tier:    -
why:     do.md row "is my setup stale" → /setup-project-health
```

```route
id:      RT-097
ask:     turn this idea into user stories: customers should be able to split a bill with friends
command: /analyze-task
tier:    -
decoy:   money idea, but the ask is a spec, not a build
why:     do.md row "user stories / turn this idea into a spec" → /analyze-task
```

```route
id:      RT-098
ask:     review the checkout flow for accessibility
command: /design-review
tier:    -
decoy:   checkout (money) noun in a read-only a11y review
why:     do.md row "review + a11y" → /design-review
```

```route
id:      RT-099
ask:     make the refund button use the brand red — don't change what it does
command: /enhance-ui
tier:    -
decoy:   money word + negation on a single-surface visual change
why:     do.md row "match colors + single UI surface" → /enhance-ui
```

```route
id:      RT-100
ask:     have Codex take a crack at backfilling the missing unit tests
command: /delegate
tier:    -
why:     do.md row "names another AI coding CLI as the implementer" → /delegate (level D)
```

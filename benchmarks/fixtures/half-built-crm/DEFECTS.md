# Seeded gaps — `half-built-crm`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first.

Fixture shape: `smallcrm`, a FastAPI + SQLite CRM that is genuinely half-built. Contacts
are the finished reference domain (full CRUD, validation, tests); deals and tasks were
started from it and stopped at different points. 16 gaps seeded across all six
`/roadmap` completion detectors. Primary target command: **`/roadmap`**.

These are **missing capabilities, not defects in working code** — the distinction
`/roadmap` and `/audit` are split on. Nothing here is a bug in shipped behaviour; every
item is something the project says or implies it should have and does not.

Two entries anchor on an *absence* (`CRM-ASYM-01`, `CRM-ASYM-04`). An absence has no line
of its own, so each anchors at its **evidence site** — the module declaration or the file
that shows the asymmetry — and the prose names what is missing.

Line numbers are exact and re-checked by `benchmarks/run.sh --verify`.

## Summary

| id | file:line | severity | command | detector |
|----|-----------|----------|---------|----------|
| CRM-STUB-01 | `app/routers/deals.py:10` | high | `/roadmap` | 1 stubs-and-placeholders |
| CRM-STUB-02 | `app/routers/deals.py:39` | high | `/roadmap` | 1 stubs-and-placeholders |
| CRM-STUB-03 | `app/services/importer.py:27` | high | `/roadmap` | 1 stubs-and-placeholders |
| CRM-STUB-04 | `app/services/exporter.py:4` | medium | `/roadmap` | 1 stubs-and-placeholders |
| CRM-WIRE-01 | `app/services/mailer.py:16` | high | `/roadmap` | 2 dangling-wires |
| CRM-WIRE-02 | `app/config.py:12` | medium | `/roadmap` | 2 dangling-wires |
| CRM-WIRE-03 | `migrations/003_add_deal_stage.sql:1` | high | `/roadmap` | 2 dangling-wires |
| CRM-WIRE-04 | `templates/tasks.html:6` | high | `/roadmap` | 2 dangling-wires |
| CRM-WIRE-05 | `templates/base.html:9` | medium | `/roadmap` | 2 dangling-wires |
| CRM-ASYM-01 | `app/routers/deals.py:5` | high | `/roadmap` | 3 feature-asymmetry |
| CRM-ASYM-02 | `app/routers/tasks.py:6` | medium | `/roadmap` | 3 feature-asymmetry |
| CRM-ASYM-03 | `app/routers/deals.py:29` | high | `/roadmap` | 3 feature-asymmetry |
| CRM-ASYM-04 | `tests/test_contacts.py:5` | medium | `/roadmap` | 3 feature-asymmetry |
| CRM-SPEC-01 | `README.md:22` | high | `/roadmap` | 4 spec-delta |
| CRM-SPEC-02 | `README.md:24` | high | `/roadmap` | 4 spec-delta |
| CRM-TABLE-01 | `app/config.py:8` | medium | `/roadmap` | 5 domain-table-stakes |

Severity split: 0 critical · 9 high · 7 medium · 0 low.
Detector coverage: 1 (×4) · 2 (×5) · 3 (×4) · 4 (×2) · 5 (×1) · 6 — see note below.

> Detector 6 (dead-end flows) is deliberately covered by `CRM-STUB-02` and `CRM-WIRE-04`
> rather than by a separate item: a `501` on a documented flow and a form posting to a
> route that does not exist are both dead ends. Scoring does not require the agent to
> name the detector — only to find the gap.

---

## CRM-STUB-01 — Deal list returns hardcoded mock rows

```defect
id:       CRM-STUB-01
file:     app/routers/deals.py
line:     10
severity: high
command:  /roadmap
class:    stub/mock-data
anchor:   # TODO: read from the deals table once the pipeline view settles.
match:    mock|hard.?cod|fake|stub|placeholder|\btodo\b|static (data|list|rows)|not (reading|querying|backed)|dummy
```

`GET /api/deals` returns two literal dictionaries and never touches the `deals` table,
which exists and is populated by `create_deal` in the same file. Anything reading the
pipeline sees the same two rows forever.

## CRM-STUB-02 — Deal conversion is a documented flow that returns 501

```defect
id:       CRM-STUB-02
file:     app/routers/deals.py
line:     39
severity: high
command:  /roadmap
class:    stub/not-implemented
anchor:   raise HTTPException(status_code=501, detail="not_implemented")
match:    501|not.?implemented|unimplemented|dead.?end|convert|stub|placeholder|returns an error
```

`POST /api/deals/{id}/convert` is routed and reachable but raises `501`. `README.md:26`
lists deal conversion as committed 1.0 scope, so this is a wired dead end rather than an
undecided feature.

## CRM-STUB-03 — CSV import parsing and dry-run are unimplemented

```defect
id:       CRM-STUB-03
file:     app/services/importer.py
line:     27
severity: high
command:  /roadmap
class:    stub/not-implemented
anchor:   # TODO: dry-run preview — normalise, dedupe against existing contacts by email,
match:    NotImplementedError|not.?implemented|\btodo\b|stub|csv|import|dry.?run|preview|unfinished
```

`preview_import` and `run_import` both raise `NotImplementedError`. `sniff_columns` above
them is written but has no caller, and there is no upload endpoint or column-mapping
screen anywhere in `app/`. `README.md:19` commits CSV import to 1.0 and `config.py:13`
already carries an `ENABLE_CSV_IMPORT` flag for it.

## CRM-STUB-04 — CSV export is a signature with no body

```defect
id:       CRM-STUB-04
file:     app/services/exporter.py
line:     4
severity: medium
command:  /roadmap
class:    stub/not-implemented
anchor:   def export_contacts(filter_query: str | None = None) -> bytes:
match:    NotImplementedError|not.?implemented|export|stub|empty (body|function|implementation)|signature only|unfinished
```

`export_contacts` raises `NotImplementedError`, has no caller and no route. `README.md:21`
commits export — whole list or filtered subset — to 1.0; the `filter_query` parameter is
the only trace of that intent.

## CRM-WIRE-01 — Mailer reads settings that do not exist

```defect
id:       CRM-WIRE-01
file:     app/services/mailer.py
line:     16
severity: high
command:  /roadmap
class:    dangling-wire/missing-config
anchor:   with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
match:    SMTP|config|setting|attribute.{0,20}(error|missing|not (defined|set))|undefined|never (defined|set|configured)|mail
```

`send()` reads `settings.SMTP_HOST` and `settings.SMTP_PORT`. Neither field exists on
`Settings` (`app/config.py`), so the first call raises `AttributeError`. Nothing calls
`send_task_reminder` either, so the whole outbound-email path is wired at one end only.

## CRM-WIRE-02 — Feature flags defined but never read

```defect
id:       CRM-WIRE-02
file:     app/config.py
line:     12
severity: medium
command:  /roadmap
class:    dangling-wire/ungated-flag
anchor:   ENABLE_WEBHOOKS: bool = os.environ.get("CRM_ENABLE_WEBHOOKS", "0") == "1"
match:    (feature )?flag|ENABLE_|toggle|never (read|used|checked|gated)|no (consumer|gate)|unused (setting|flag|config)|dead config
```

`ENABLE_WEBHOOKS` (line 12) and `ENABLE_CSV_IMPORT` (line 13) are both defined and neither
is read anywhere in the tree. `ENABLE_WEBHOOKS` in particular gates a feature that has no
code at all — there is no webhook module, route or delivery path.

## CRM-WIRE-03 — Migration adds columns nothing consumes

```defect
id:       CRM-WIRE-03
file:     migrations/003_add_deal_stage.sql
line:     1
severity: high
command:  /roadmap
class:    dangling-wire/unconsumed-migration
anchor:   ALTER TABLE deals ADD COLUMN stage TEXT NOT NULL DEFAULT 'lead';
match:    migration|schema|column|stage|unused|no (consumer|code|reader)|never (read|selected|written|surfaced)|not exposed|orphan
```

`003_add_deal_stage.sql` adds `deals.stage`, `deals.stage_changed_at` and an index on
`stage`. No query selects or writes any of them: `list_deals` returns mocks,
`get_deal` and `create_deal` name only `title`, `value_cents` and `contact_id`. The deal
pipeline described in `README.md:11-12` is the missing capability this migration was
preparing for.

## CRM-WIRE-04 — Bulk-action form posts to a route that does not exist

```defect
id:       CRM-WIRE-04
file:     templates/tasks.html
line:     6
severity: high
command:  /roadmap
class:    dangling-wire/missing-route
anchor:   <form method="post" action="/api/tasks/bulk">
match:    bulk|form|no (matching |backing )?(route|handler|endpoint)|missing (route|handler|endpoint)|404|action=|submit target|not routed
```

The tasks template submits to `/api/tasks/bulk` with `action=complete` or `action=delete`.
`app/routers/tasks.py` registers no `bulk` route, so both buttons are dead. The delete
button is also the only delete affordance for tasks anywhere in the UI — see CRM-ASYM-02.

## CRM-WIRE-05 — Navigation links to pages that were never built

```defect
id:       CRM-WIRE-05
file:     templates/base.html
line:     9
severity: medium
command:  /roadmap
class:    dangling-wire/missing-route
anchor:   <a href="/contacts">Contacts</a>
match:    nav|link|no (page|route|handler|view)|missing (page|route|view)|404|html route|server.?rendered|template.{0,20}(unused|never rendered)|dead link
```

`base.html` links to `/contacts`, `/deals` and `/tasks`. `app/main.py` registers only the
`/api/*` routers and `/healthz` — none of those three paths exists. `main.py:7` constructs
a `Jinja2Templates` instance that nothing uses, so `tasks.html` is never rendered by any
code path.

## CRM-ASYM-01 — Deals module is missing update and delete

```defect
id:       CRM-ASYM-01
file:     app/routers/deals.py
line:     5
severity: high
command:  /roadmap
class:    asymmetry/partial-crud
anchor:   router = APIRouter(prefix="/api/deals", tags=["deals"])
match:    crud|(missing|no) (update|delete|put|patch)|partial|incomplete|asymmetr|edit|contacts (has|have)|parity
```

`contacts.py` implements list / get / create / update / delete. `deals.py` implements
list / get / create and stops — there is no `PUT` and no `DELETE`. A deal can be created
and never corrected or removed.

## CRM-ASYM-02 — Tasks module is missing delete

```defect
id:       CRM-ASYM-02
file:     app/routers/tasks.py
line:     6
severity: medium
command:  /roadmap
class:    asymmetry/partial-crud
anchor:   router = APIRouter(prefix="/api/tasks", tags=["tasks"])
match:    crud|(missing|no) delete|partial|incomplete|asymmetr|remove|parity
```

`tasks.py` implements list / get / create / update but no `DELETE`, while `contacts.py`
has one. The tasks template already renders a "Delete selected" button (CRM-WIRE-04), so
the UI is ahead of the API here.

## CRM-ASYM-03 — Deal creation takes an unvalidated raw dict

```defect
id:       CRM-ASYM-03
file:     app/routers/deals.py
line:     29
severity: high
command:  /roadmap
class:    asymmetry/missing-validation
anchor:   def create_deal(payload: dict):
match:    validat|schema|pydantic|BaseModel|raw dict|untyped|no (model|schema|validation)|response_model|typed payload
```

`create_deal` accepts `payload: dict` and reads keys with `.get()`, so a missing `title`
inserts `None` into a `NOT NULL` column and a missing `contact_id` breaks the foreign key.
Every other write endpoint in the project takes a pydantic model from `app/schemas.py`,
and `schemas.py` has no `DealIn` / `DealOut` pair at all — unlike contacts and tasks.

## CRM-ASYM-04 — Only the contacts domain has tests

```defect
id:       CRM-ASYM-04
file:     tests/test_contacts.py
line:     5
severity: medium
command:  /roadmap
class:    asymmetry/missing-tests
anchor:   client = TestClient(app)
match:    test|coverage|untested|no tests|missing tests|test_deals|test_tasks|asymmetr|only.{0,20}contacts
```

`tests/` holds one file. Contacts have five tests covering create, get, validation
rejection, update, delete and search. Deals and tasks have none, so every gap above in
those two modules is also invisible to CI.

## CRM-SPEC-01 — Email notifications are promised and absent

```defect
id:       CRM-SPEC-01
file:     README.md
line:     22
severity: high
command:  /roadmap
class:    spec-delta/promised-not-built
anchor:   - **Email notifications** — when a deal changes stage, notify the deal owner and anyone
match:    (email )?notif|readme|promis|documented|spec|stage change|watcher|digest|subscri|not (built|implemented|present)
```

`README.md:22-23` commits stage-change notifications with a watcher list and a daily
digest. What exists is `mailer.py`, whose only concrete function is a task reminder that
nothing calls, and which cannot run at all (CRM-WIRE-01). There is no watcher table, no
subscription concept, no digest job and no stage-change event to hang one on.

## CRM-SPEC-02 — Role-based permissions are promised and unenforced

```defect
id:       CRM-SPEC-02
file:     README.md
line:     24
severity: high
command:  /roadmap
class:    spec-delta/promised-not-built
anchor:   - **Role-based permissions** — `owner`, `member` and `viewer`. Viewers can read everything
match:    (role|rbac|permission|authoriz|access control)|viewer|owner|member|enforce|readme|promis|spec|no (auth|check|gate)
```

`README.md:24-25` specifies three roles with distinct write and delete rights. The whole
implementation is a `role TEXT NOT NULL DEFAULT 'member'` column on `users`
(`migrations/001_init.sql:14`). There is no authentication, no session (`session_secret`
in `config.py:9` is unread), no current-user concept and no check on any endpoint — every
route is fully open.

## CRM-TABLE-01 — No list endpoint paginates

```defect
id:       CRM-TABLE-01
file:     app/config.py
line:     8
severity: medium
command:  /roadmap
class:    table-stakes/pagination
anchor:   page_size: int = 50
match:    paginat|page.?size|limit|offset|cursor|unbounded|all rows|no (limit|paging)|infinite scroll
```

`page_size` is configured and never read. `list_contacts`, `list_deals` and `list_tasks`
all return every matching row with no `LIMIT`, no offset and no cursor, and the templates
render the full set. Pagination is table stakes for a list surface in this domain, and the
config field shows it was intended.

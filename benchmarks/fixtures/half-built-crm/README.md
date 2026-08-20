# smallcrm

A CRM for two-person sales teams. Contacts, deals, tasks. FastAPI + SQLite, server-rendered
templates for the few screens that need them.

Status: **work in progress.** Contacts are done. Deals and tasks are partly there.

## What it does

- **Contacts** — full CRUD, searchable, with an activity trail.
- **Deals** — pipeline of opportunities attached to a contact, each with a value and a
  stage (`lead` → `qualified` → `proposal` → `won` / `lost`).
- **Tasks** — follow-ups attached to a contact or a deal, with a due date.

## What it will do

These are committed scope for 1.0, not ideas:

- **CSV import** — bulk-load contacts from an exported spreadsheet, with a column-mapping
  step and a dry-run preview before anything is written.
- **CSV export** — the same in reverse, for the whole contact list or a filtered subset.
- **Email notifications** — when a deal changes stage, notify the deal owner and anyone
  watching that contact. Digest option for the daily summary.
- **Role-based permissions** — `owner`, `member` and `viewer`. Viewers can read everything
  but write nothing; members cannot delete; owners can do anything and manage the team.
- **Deal conversion** — turn a won deal into a customer record, carrying the contact and
  the deal history across.

## Running it

```
uvicorn app.main:app --reload
```

Migrations in `migrations/` are applied in filename order by `scripts/migrate.sh`.

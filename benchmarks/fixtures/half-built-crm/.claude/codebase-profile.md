# Codebase profile — smallcrm

PROJECT_KIND: backend-service
Language: Python 3.11
Framework: FastAPI
Datastore: SQLite (raw SQL, no ORM)
Templates: Jinja2, server-rendered for the bulk-action screens
Tests: pytest

## State

Contacts are the finished reference domain: full CRUD, validation, tests. Deals and tasks
were started from the contacts module and are at different stages of completion.

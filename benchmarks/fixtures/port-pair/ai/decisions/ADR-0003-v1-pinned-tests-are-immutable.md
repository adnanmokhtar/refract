# ADR-0003 — V1-pinned parity tests and goldens are immutable in port PRs

Status: Accepted (2026-07-02)

The parity suites under `v2/apps/api/test/parity/` and their `__golden__/` files are recorded from
V1 at the ledger pin. A port PR may not edit, skip or re-record them. A case that differs on
purpose is changed in its own PR, with an ADR and a `changes_baseline` entry on the ledger row,
before the port PR that relies on it.

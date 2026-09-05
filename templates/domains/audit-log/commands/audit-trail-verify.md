---
description: Verify the audit trail end-to-end — recompute the hash chain / sequence integrity against the stored values, AND prove coverage of a checklist of sensitive actions (each must cite its emit site or FAIL).
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-trail-verify

Prove the audit log is actually trustworthy — that the chain is intact AND every sensitive action is actually captured. Two independent checks, both cite-or-fail: integrity (the rows that exist are unaltered and ungapped) and coverage (the rows that SHOULD exist are emitted somewhere in the code).

## Premise

Real signals only. Integrity is reported as the ACTUAL computed-vs-stored hash result over a real row range — never an assumed pass. Coverage is reported as the ACTUAL emit site at `<path:line>` for each sensitive action — or FAIL for that action. Read before writing: confirm the audit store / table, the integrity scheme (hash chain vs anchored seq), and the canonical-serialization function BEFORE computing anything. Never narrate a verification you didn't run; never print "chain OK" without the row range and the head hash you recomputed.

## Mechanical halt

Cite-or-halt on BOTH axes:
- **Integrity** — every reported segment prints the row range checked, the recomputed `row_hash` vs the stored `row_hash` for the boundary rows, and the first divergent `seq` (or "0 gaps / 0 mismatches over [lo..hi]"). If the table has no `prev_hash`/`row_hash` and no monotonic anchored `seq`, HALT — there is nothing to verify; report it as a BLOCKER, not a pass.
- **Coverage** — every sensitive action in the checklist maps to an emit site at `<path:line>` (the `record(...)` / `@Audit(...)` reached on that handler's committed path) or is reported FAIL. A sensitive action with no emit site, or one whose emit is on a swallowed / fire-and-forget path, is a FAIL — never assumed present.

READ-ONLY against data: this command SELECTs and recomputes; it MUST NOT insert, update, or delete audit rows. Run against a snapshot / read replica when verifying production.

## What it does

1. **Resolve the scheme.** Locate the audit table/store, the `prev_hash`/`row_hash` columns (or the monotonic `seq` + anchoring records), the `hash_version` column, and the canonical-serialization function used to hash. Cite each at `<path:line>`.
2. **Recompute the chain.** Walk rows by `seq` over the requested range (default: last 30 days, or `--from <seq> --to <seq>`):
   - For each row, recompute `row_hash = H(prev_hash ‖ canonical(row))` using the function for that row's `hash_version`.
   - Assert recomputed == stored `row_hash`.
   - Assert this row's `prev_hash` == previous row's stored `row_hash`.
   - Assert `seq` is strictly monotonic and gap-free (no missing seq between lo and hi).
   - If anchoring is used, recompute the head hash for each anchored window and compare against the stored/notarized anchor.
3. **Report integrity.** Row range, total rows, mismatches (with the first divergent `seq` + computed vs stored), gaps (missing seq ranges), and anchor results. Any mismatch/gap = integrity FAIL.
4. **Build the coverage checklist.** The sensitive-action set (from the closed `AuditAction` enum + project ADR): auth login/login-failed/logout/MFA, role/permission grant+revoke, data export/bulk read, admin override, impersonation start/stop, record delete/anonymize, audit read/export.
5. **Locate each emit site.** For each sensitive action, find where it is emitted (`record(action)` call, `@Audit(action)` marker) AND confirm the emit is on the committed path (same-txn or outbox) — not a swallowed async / fire-and-forget. Cite `<path:line>` or mark FAIL.
6. **Cross-check handlers.** Grep the destructive / privileged handlers (`@Delete`, role mutations, export endpoints, impersonation) and assert each reaches an emit. A handler with no reachable emit = coverage FAIL (cite the handler).
7. **Report coverage.** Each action → emit site `<path:line>` or FAIL; each sensitive handler → reached/UNREACHED.

## Flow

```text
resolve scheme (table, prev_hash/row_hash | seq+anchor, hash_version, canonical fn)
  ↓  (no integrity primitive → HALT: report BLOCKER)
recompute chain over [from..to]
  → per row: recomputed row_hash == stored?  prev_hash links?  seq monotonic+gap-free?
  → anchors recompute == stored?
  ↓
INTEGRITY: range, mismatches (first divergent seq + computed-vs-stored), gaps, anchors
  ↓
coverage checklist (closed AuditAction enum + ADR)
  → each action → emit site <path:line> (committed path) | FAIL
  → each sensitive handler → reaches an emit | UNREACHED
  ↓
COVERAGE: per-action + per-handler table
```

## Usage

```bash
/audit-trail-verify                          # integrity over last 30 days + full coverage checklist
/audit-trail-verify --from 1 --to 50000      # integrity over an explicit seq range
/audit-trail-verify --coverage-only          # skip the chain recompute; only prove emit-site coverage
/audit-trail-verify --integrity-only         # skip coverage; only recompute the chain
/audit-trail-verify --replica                # run against the read replica / snapshot (recommended for prod)
```

## Output

```
/audit-trail-verify — <scope>

Integrity (hash-chain, sha256, hash_version=1):
  range:      seq 49,001 .. 50,000  (1,000 rows)
  hash check: 1,000/1,000 recomputed == stored
  links:      999/999 prev_hash match
  gaps:       0  (seq strictly monotonic, gap-free)
  anchors:    3/3 windows match notarized head
  RESULT:     PASS

  -- on failure --
  RESULT:     FAIL
  first mismatch: seq=49,318
    computed row_hash: 9f3a…c1   stored row_hash: 00ab…7e   → row altered after write
  gap: seq 49,400..49,402 missing (3 rows) → deletion or chain break

Coverage (sensitive actions → emit site, committed path):
  auth.login              src/auth/auth.service.ts:88        OK
  auth.login.failed       src/auth/auth.service.ts:104       OK
  authz.role.granted      src/authz/role.controller.ts:42    OK
  authz.role.revoked      src/authz/role.controller.ts:61    OK
  data.exported           FAIL — /reports/export reaches no record(...)
  admin.override          src/admin/override.ts:33           OK
  admin.impersonation.*   src/admin/impersonate.ts:20        OK
  record.deleted          FAIL — DELETE /users/:id (user.admin.controller.ts:48) UNREACHED
  audit.read              src/audit/audit.query.controller.ts:14  OK

  Handlers without reachable emit:
    - user.admin.controller.ts:48  @Delete('/users/:id')   → no record(...) on committed path

VERDICT: FAIL (1 integrity mismatch + 1 gap; 2 coverage gaps)
```

## Rules

- READ-ONLY against the audit store — SELECT + recompute only. Never INSERT/UPDATE/DELETE an audit row. Prefer a replica/snapshot for production runs.
- Integrity result is the ACTUAL computed-vs-stored comparison over a real row range — never "looks fine." A mismatch or gap is a FAIL with the first divergent `seq` cited.
- No integrity primitive in the schema (no hash chain, no anchored monotonic seq) → HALT and report a BLOCKER; do not emit a green result.
- Coverage is cite-or-FAIL: each sensitive action prints its emit `<path:line>` on the committed path, or FAILs. An emit on a swallowed / fire-and-forget path counts as FAIL.
- Use the `hash_version`-correct canonical-serialization function per row; a verifier mismatch from using the wrong serializer is a verifier bug, not a tampering finding — fix the verifier first.

---
description: Enumerate every admin / back-office endpoint + action and audit each for authorization granularity, audit coverage, impersonation safety, destructive-action guards, cross-tenant reach, mass-action blast-radius, and PII exposure — from real source, never an assumed map.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /audit-admin-surface

Map the entire staff-facing admin surface and verify each action is capability-gated, audited, impersonation-safe, destructive-guarded, tenant-explicit, blast-radius-bounded, and PII-justified — from the REAL handlers, not a guess at what "should" be there.

## Premise

Real signals only. For EVERY admin endpoint / action, cite the handler at `<path:line>`, the authorization check at `<path:line>` (and whether it is a granular capability or a blanket `is_admin` / `role === 'admin'` flag), the audit-event write at `<path:line>` (and whether it commits BEFORE the response), and — where applicable — the impersonation attribution, the step-up/typed-confirm guard, the cross-tenant predicate, the blast-radius cap, and the PII handling, each at `<path:line>`. "The admin panel looks fine" without the files is noise. Read before auditing: locate every admin handler in source and confirm its guards BEFORE issuing a verdict.

## Mechanical halt

Cite-or-halt: every admin action in the matrix MUST show (1) the handler at `<path:line>`, (2) the authorization check at `<path:line>` classified as CAPABILITY or BLANKET, (3) the audit write at `<path:line>` classified as BEFORE-RESPONSE / AFTER / MISSING / FIRE-AND-FORGET, and (4) the applicable guard verdicts (impersonation, destructive, cross-tenant, blast-radius, PII). If any of these cannot be produced from real source, HALT and name the action + what's missing — never an assumed gate, never an assumed audit.

If the admin surface cannot be located at all (no admin module / routes found), HALT and ask where the staff-facing surface lives — do NOT report "no admin surface, looks safe."

## What it does

1. **Enumerate** every admin / back-office / support-console / moderation / super-admin endpoint + action — cite each handler at `<path:line>`. Include impersonation start/stop and any bulk/mass operations.
2. **Authorization granularity** — for each action, cite the authz check. Is it a SPECIFIC capability (`refunds.issue`, `tenants.delete`) or a blanket `is_admin` / `role === 'admin'`? A blanket flag is a finding (BLOCKER).
3. **Audit coverage** — for each MUTATING action, cite the audit-event write. Does it record actor + target + before/after + reason, and commit BEFORE the response? Missing / after-the-fact / fire-and-forget audit is a finding.
4. **Impersonation safety** — for any act-as feature, confirm a visible banner, a scoped + expiring session, and that every impersonated action is attributed to the REAL staff actor (`actorId = staffId`, `onBehalfOf = userId`). Start/stop audited. Any gap is a finding.
5. **Destructive-action guards** — for irreversible actions (delete / wipe / refund-all / disable), confirm step-up reauth + typed target confirmation. A bare destructive endpoint is a finding.
6. **Cross-tenant reach** — for each query, is the tenant predicate present, OR is the reach widened? If widened, is it via an explicit capability AND recorded in the audit event? A silently dropped predicate is a finding (BLOCKER).
7. **Mass-action blast-radius** — for each bulk action, confirm a hard cap AND/OR maker-checker by a different actor. Uncapped + unapproved bulk is a finding.
8. **PII exposure** — for each view/list, is sensitive data masked by default with capability-gated, audited reveal — or `SELECT *` firehosed inline? Unjustified bulk PII is a finding.
9. **Report** — the admin-surface matrix with per-action verdicts + the ranked list of blockers/requests.

## Flow

```text
enumerate admin actions (<path:line> each)
  -> authz check: CAPABILITY | BLANKET is_admin            [BLOCKER if blanket]
  -> audit write: BEFORE | AFTER | MISSING | FIRE-FORGET   [BLOCKER if missing on a mutation]
  -> impersonation: banner+scope+expiry+attribution        [finding if any gap]
  -> destructive: step-up reauth + typed confirm           [BLOCKER if bare]
  -> cross-tenant: scoped | explicit-cap+audit | DROPPED   [BLOCKER if silently dropped]
  -> bulk: cap and/or maker-checker                        [finding if uncapped+unapproved]
  -> PII: masked+gated+audited | firehose                  [finding if firehose]
  -> report: admin-surface matrix + ranked findings
```

## Output

```
/audit-admin-surface — <scope>

Admin-surface matrix:
  action                  handler              authz            audit              imperson   destructive   x-tenant            bulk            pii
  ----------------------  -------------------  ---------------  -----------------  ---------  ------------  ------------------  --------------  -----------------
  refund.issue            refunds.ctrl.ts:22   CAPABILITY✓      BEFORE✓            n/a        n/a           scoped✓             n/a             n/a
  tenant.delete           tenants.ctrl.ts:40   CAPABILITY✓      BEFORE✓            n/a        REAUTH+TYPED✓ scoped✓             n/a             n/a
  users.list             users.ctrl.ts:11      BLANKET is_admin AFTER(!)           n/a        n/a           DROPPED(!)          n/a             FIREHOSE(!)
  user.impersonate        imp.svc.ts:18         CAPABILITY✓      start/stop✓        BANNER?    n/a           scoped✓             n/a             n/a
  refund.bulk             bulk.svc.ts:30        CAPABILITY✓      BEFORE✓            n/a        n/a           scoped✓             NO CAP / NO 2nd  n/a

Findings (ranked):
  BLOCKER  users.list @ users.ctrl.ts:11 — blanket is_admin gate + dropped tenant predicate + SELECT * PII firehose
  BLOCKER  refund.bulk @ bulk.svc.ts:30 — no blast-radius cap, no maker-checker (one actor mass-refunds)
  REQUEST  user.impersonate @ imp.svc.ts:18 — impersonation session present but no visible banner confirmed in UI

Verdict: OK | NEEDS-CHANGES | BLOCKER
Coverage: <N> admin actions enumerated, <M> with complete guards, <K> with findings.
```

## Rules

- READ-ONLY diagnostic. Enumerate + classify; never mutate, never call an admin action, never start an impersonation session to "test" it.
- Cite-or-halt: real handler, real authz check, real audit write, real guards — or halt naming the action + what's missing.
- Always classify authz as CAPABILITY vs BLANKET and audit as BEFORE/AFTER/MISSING/FIRE-AND-FORGET — never "looks authed / looks logged."
- A blanket `is_admin` gate, a missing audit write on a mutation, a bare destructive action, and a silently dropped tenant predicate are reported FIRST, as blockers.
- If the admin surface can't be located, halt and ask — never report "no admin surface, safe."

## Cross-references

- `.claude/rules/admin-backoffice-discipline.md` — the hard-rule list this command enforces (granular capability, audit-before-return, impersonation safety, destructive guards, dual-control / blast-radius, explicit cross-tenant, PII).
- `ai/patterns/admin-action.md` — the capability check + audited wrapper + impersonation attribution + step-up/typed-confirm + dual-control + blast-radius code shapes.
- `<rules-path>/audit-log-discipline.md` — the tamper-evident audit-write contract each action is checked against.
- `<rules-path>/auth-discipline.md` — capability model, step-up reauth, MFA, admin session/origin separation.
- `<rules-path>/multi-tenancy.md` — explicit-and-audited cross-tenant reach vs a dropped predicate.
- `<agents-path>/admin-reviewer.md` — review gate that consumes these findings.

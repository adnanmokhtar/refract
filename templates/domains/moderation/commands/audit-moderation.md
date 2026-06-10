---
description: Audit the content-moderation pipeline — where UGC enters, scan coverage (pre/post-publish + edit re-scan), illegal-content handling (hash-match + mandatory report), action audit/attribution, appeal path, reporter PII, report rate-limit, and moderator over-privilege — against real code, never an assumed pipeline.
---

# /audit-moderation

Diagnose whether user-generated content is actually moderated before it reaches users, whether illegal content is preserved+reported rather than silently dropped, whether every action is accountable and appealable, and whether the reporting system can't be weaponized — from the REAL code paths, not a guess.

## Premise

Real signals only. Cite where UGC ENTERS at `<path:line>`, the scan gate (classifier + hash-match) at `<path:line>`, the illegal-content path at `<path:line>`, the audited+attributed action write at `<path:line>`, the appeal route at `<path:line>`, the target-facing report serializer at `<path:line>`, the report rate-limit at `<path:line>`, and the moderator capability scope at `<path:line>` — never narrate a pipeline you didn't read. Read before judging: trace one UGC item from creation to the feed AND from edit back to the scanner BEFORE concluding anything.

## Mechanical halt

Cite-or-halt: every run MUST print, for each UGC surface, (1) where content enters at `<path:line>`, (2) the scan gate and whether it runs BOTH a classifier AND a known-illegal hash-match (or "MISSING"), (3) whether unscanned content can reach a feed/search/notify surface (pre vs. post-publish, and edit re-scan), (4) the illegal-content handling — hash-match → preserve + mandatory report + lockdown, or "SILENT DELETE / NONE", (5) whether every moderation action is attributed + reasoned + audited at `<path:line>`, (6) the appeal/reversal path (or "NONE"), (7) whether reporter PII can reach the reported user, (8) the report rate-limit + brigading guard, and (9) whether moderators are over-privileged beyond their scope. If any of these cannot be produced from real code, HALT and say which — never an assumed pipeline, never an assumed scan.

READ-ONLY. This command traces and reports; it does not modify content, take moderation actions, run the scanner against real uploads, or touch the illegal-content evidence store.

## What it does

1. **Locate UGC ingress** — every surface where users create content others can see (post / comment / image / video / DM / profile / review / upload). Cite each create + edit handler at `<path:line>`.
2. **Trace to distribution** — for each surface, follow content to the feed/search/notify layer. Is there a scan gate between creation and distribution? Pre-publish, or post-publish-before-distribution? Cite the gate or flag UNSCANNED.
3. **Inspect the scan** — does it run an automated classifier AND a known-illegal hash-match? A classifier-only scan is a finding; the hash-match is decisive and must run. Cite both at `<path:line>`.
4. **Trace the illegal-content path** — what happens on a hash-match? Preserve (write-once) + mandatory report + account lockdown on an isolated trail, or a silent `delete`, or nothing? A silent delete is a BLOCKER. Cite at `<path:line>`.
5. **Check edit re-scan** — does editing already-approved content re-run the scan idempotently, or bypass it? Cite the edit path at `<path:line>`.
6. **Audit the actions** — is every action (remove/ban/shadow/age_gate) attributed to a real actor (or named rule), reasoned, and written to the audit log BEFORE effect? Cite the audit write at `<path:line>`.
7. **Check the appeal path** — is every reversible action appealable, decided by a DIFFERENT actor? Cite or flag NONE.
8. **Check reporter PII** — does the target-facing report view exclude the reporter's identity/PII? Cite the serializer at `<path:line>`; if the reporter id can reach the target, flag RETALIATION VECTOR.
9. **Check report rate-limit** — per-reporter rate limit + (reporter,target) dedup + brigade-resistant weighting on auto-action? Cite or flag BRIGADING.
10. **Check moderator privilege** — is moderator capability scoped least-privilege + attributed to an individual, or broad/shared? Cite at `<path:line>`.
11. **Report** — per-surface coverage matrix + the BLOCKER spine + top recommendation.

## Flow

```text
locate UGC ingress (<path:line>)  [per surface: post/comment/image/video/dm/profile]
  -> trace to distribution (feed/search/notify)
       -> scan gate present?                         [BLOCKER if UNSCANNED served]
       -> classifier AND hash-match?                 [finding if classifier-only]
  -> hash-match -> preserve + report + lockdown?     [BLOCKER if SILENT DELETE / none]
  -> edit re-scans idempotently?                     [BLOCKER if edit bypass]
  -> action attributed + reasoned + audited?         [BLOCKER if unaccountable]
  -> appeal path, decided by a different actor?       [BLOCKER if none]
  -> reporter PII absent from target view?            [BLOCKER if reporter reachable]
  -> reports rate-limited + brigade-resistant?        [BLOCKER if count auto-removes]
  -> moderator capability scoped + attributed?        [finding if over-privileged]
  -> report: coverage matrix + BLOCKER spine + top recommendation
```

## Output

```
/audit-moderation — <scope>

UGC surfaces:
  posts      ingress @ post.controller.ts:22   scan=pre-publish  classifier+hash=OK   edit-rescan=OK
  comments   ingress @ comment.controller.ts:18 scan=post-publish classifier+hash=OK   edit-rescan=OK
  images     ingress @ upload.controller.ts:31  scan=pre-publish  classifier+hash=OK   edit-rescan=N/A
  dms        ingress @ message.service.ts:40    scan=MISSING(!)   classifier+hash=—    edit-rescan=—

Illegal-content path:  @ illegal-content.pipeline.ts:14
  hash-match -> preserve(write-once)=OK  mandatory-report=OK  lockdown=OK  silent-delete=NONE   [or: SILENT DELETE — BLOCKER]

Actions:    attributed=OK  reason=OK  audited-before-effect @ moderation-action.service.ts:33   [or: UNATTRIBUTED — BLOCKER]
Appeal:     present @ appeal.service.ts:25  different-actor=OK                                  [or: NONE — BLOCKER]
Reporter PII: target-view @ report.target-view.ts:9  reporterId=ABSENT                          [or: REPORTER REACHABLE — BLOCKER]
Report limit: per-reporter=OK  (reporter,target)-dedup=OK  weighted-auto-action=OK              [or: COUNT AUTO-REMOVES — BLOCKER]
Moderator:    scoped @ admin.guard.ts:12  per-individual=OK                                      [or: OVER-PRIVILEGED — finding]
Scanner-on-error: fail-CLOSED @ scanner.ts:51                                                    [or: FAIL-OPEN — finding]

Verdict: OK | NEEDS-SCAN-COVERAGE | NEEDS-ILLEGAL-PATH | NEEDS-ACCOUNTABILITY | BLOCKER(unscanned-served)

Top recommendation:
  - <e.g. gate DM distribution on the scan; route hash-match to preserve+report not delete; add appeal route>
```

## Rules

- READ-ONLY. Trace and report; never take a moderation action, run the scanner against real content, or touch the evidence store.
- Cite-or-halt: real ingress, real scan gate, real illegal-content path, real audit write, real serializer — or halt naming what's missing.
- Always print the per-surface scan-coverage matrix; an unscanned surface that reaches other users is reported FIRST as a BLOCKER.
- A hash-match path that silently deletes (no preserve + no mandatory report) is a BLOCKER, reported before any classifier finding.
- An action with no actor/reason/audit, or with no appeal route, is a BLOCKER — accountability and due process are not optional.
- Never report a scan, an illegal-content path, or an appeal route you didn't read in source.

## Cross-references

- `.claude/rules/moderation-discipline.md` — the hard-rule list this command enforces (scan before serve, hash-match + mandatory report, audited action, appeal, reporter PII, rate-limit, edit re-scan, shadow leak).
- `ai/patterns/moderation-pipeline.md` — the scan → queue → audited action → appeal shapes + the illegal-content preserve+report hook.
- `<rules-path>/audit-log` — every action is an audited, attributed event.
- `<rules-path>/admin` — moderator capability is scoped admin; per-individual attribution.
- `<rules-path>/rate-limit` — per-reporter / per-target report limiting + brigading resistance.
- `<rules-path>/compliance` — the mandatory-reporting jurisdiction + evidence-retention contract.
- `<agents-path>/moderation-reviewer.md` — review gate that consumes these findings.

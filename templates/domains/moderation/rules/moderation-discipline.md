---
name: moderation-discipline
description: Content moderation & trust-safety discipline
kind: rule
---

# Content moderation & trust-safety discipline

## Hard rule

Any user-generated content (UGC) that becomes visible to other users MUST pass a moderation scan BEFORE it is served — pre-publish, OR post-publish-before-distribution — never published unscanned. The scan MUST run an automated classifier AND a hash-match against the known-illegal corpus (CSAM/terror PhotoDNA-class hashes); a positive hash-match is NOT a normal moderation decision — it MUST trigger mandatory reporting to the legal authority (e.g. NCMEC), evidence preservation, and account lockdown, on an isolated, audited code path that is NEVER silently deleted. Every moderation ACTION (remove / ban / shadow-ban / age-gate) MUST be attributed to a real actor (human or named automated rule), carry a reason + evidence reference, and be written to the append-only audit log BEFORE it takes effect. Every action MUST have an APPEAL / reversal path — a ban with no due-process route is forbidden. The reporter's identity + PII MUST NEVER be exposed to the reported user. Reports MUST be rate-limited per reporter + per target so a coordinated group cannot brigade a false-flag takedown. Re-scan MUST fire idempotently on every EDIT — approved-then-edited content that bypasses the scanner is a scan bypass.

A moderation bug is illegal or abusive content served to users, an unaccountable ban with no appeal, a retaliation vector that doxxes a reporter, or legal liability for failing to report CSAM — every one of which is a trust-and-safety incident, not a normal defect.

## Must

- **Scan before serve**: every UGC type (post, comment, image, video, message, profile field, upload) passes a moderation scan before it is visible to anyone but the author. Either gate publish on the scan, OR publish to author-only and gate DISTRIBUTION (feed/search/notify) on the scan result — never let unscanned content reach other users.
- **Automated classifier + hash-match, both**: the scan runs (1) an automated classifier (text toxicity / nudity / spam / NSFW model) for policy-grade content AND (2) a cryptographic / perceptual hash-match against the known-illegal corpus (PhotoDNA / MD5 / pHash) for CSAM and terror content. Classifier and hash-match are DISTINCT signals — a "clean" classifier score never overrides a hash-match hit.
- **Illegal-content path is isolated + mandatory-reporting + evidence-preserving**: a hash-match (or a high-confidence CSAM classifier hit) does NOT route to the normal review queue and is NEVER silently deleted. It locks the account, PRESERVES the evidence (content + metadata + uploader identity, write-once, legal-hold) and files a mandatory report to the authority (NCMEC / equivalent) — see `<rules-path>/compliance`. Deleting the evidence before the report destroys the legal record.
- **Borderline → human review queue**: content the classifier scores in the uncertain band is routed to a human-review queue (NOT auto-published, NOT auto-removed). A queue item carries the content, the signals, the reporter context, and an SLA. High-stakes automated removal/ban with no human-in-the-loop is forbidden for irreversible actions.
- **Every action is attributed + reasoned + audited**: remove / ban / shadow-ban / age-gate / restore each records `{ actorId | ruleId, targetId, contentId, action, reason, evidenceRef, at }` to the append-only audit log (see `<rules-path>/audit-log`) BEFORE the action takes effect. An automated action is attributed to the NAMED rule version, never "system".
- **Appeal / reversal path on every action**: every moderation action against a user is appealable; an appeal opens a review item, is decided by a different actor than the original (no self-review on appeal), and a reversal RESTORES state + audits the reversal. A ban with no appeal route is a due-process failure.
- **Moderator tooling = scoped admin actions**: moderator capabilities are least-privilege, scoped to the moderation surface, and every privileged action is attributed to the individual moderator (see `<rules-path>/admin`). No shared moderator account; no moderator who can act on content outside their assigned scope.
- **Reporter PII is shielded**: a report stores the reporter id internally for audit/anti-abuse, but the reported user (and any non-privileged surface) NEVER sees who reported them. Report payloads exposed to the target are reporter-anonymized.
- **Reports are rate-limited (anti-brigading)**: report submission is rate-limited per reporter AND deduplicated per (reporter, target) so one actor can't spam, and aggregated per target with a brigading heuristic so a coordinated group can't auto-trigger a takedown by volume alone (see `<rules-path>/rate-limit`). N reports never auto-remove without a weighting/threshold that resists coordination.
- **Idempotent re-scan on edit**: every EDIT to already-approved content re-runs the scan with the same idempotency key shape (`scan:<contentId>:<contentHash>`); identical content short-circuits, changed content is re-evaluated. Approved-then-edited content MUST NOT skip the scanner.
- **Shadow-ban state is server-side + leak-proof**: shadow-ban (visible to the author, hidden from others) is enforced server-side on read; the shadow flag, removed counts, and "your post was hidden" signals are NEVER leaked to the shadowed user via response shape, counts, timing, or error differences.

## Must not

- Publish or distribute UGC to other users with no moderation scan (pre- or post-publish) — illegal/abusive content served.
- Treat a known-illegal hash-match as a normal moderation decision — silently delete it, drop it in the human queue, or skip the mandatory report + evidence preservation. That is destruction of evidence + failure to report.
- Auto-take an irreversible high-stakes action (permanent ban, legal report) purely on an automated score with no human-in-the-loop where the policy requires one.
- Record a moderation action with no actor, no reason, or no audit entry — an unaccountable ban.
- Ship a ban / removal with no appeal or reversal path.
- Let the same actor decide both the original action and its appeal (self-review).
- Expose the reporter's identity, email, or any PII to the reported user, directly or by inference.
- Auto-remove content on raw report COUNT with no per-(reporter,target) dedup, no per-reporter rate limit, and no brigading-resistant weighting — false-flag takedown.
- Skip the re-scan when approved content is edited — scan bypass.
- Leak shadow-ban status to the shadowed user via different counts, response shape, timing, or error messages.
- Grant moderators broad/admin privileges beyond their scope, or act via a shared moderator login that can't be attributed to an individual.

## Should

- Wrap the scan behind a project-internal `<ModerationPipeline>` / `<Scanner>` interface so classifier + hash-match + queue routing + audit are enforced in one place — feature code submits content, it does not hand-roll a scan per call site.
- Version the policy + classifier model + hash corpus and stamp each scan result with the versions used, so a decision is reproducible and a model change is auditable.
- Express moderation actions as a closed action vocabulary (`remove | restore | ban | unban | shadow | unshadow | age_gate | report_illegal`) with declared reversibility + required reason + required evidence per action.
- Route reporter-facing and target-facing report views through distinct serializers so reporter PII physically cannot reach the target serializer.
- Emit structured `{ contentId, scanResult, classifierScore, hashMatch, queueRoute, actorId|ruleId, action, latencyMs }` per decision; alert on hash-match events, on scan errors that fail-open, and on report-volume spikes against a single target (brigading).
- Fail CLOSED on scanner error for content that hasn't been cleared — hold for review, never auto-publish on a scan timeout/exception.

## Review checklist (PRs touching UGC ingest, scanning, reporting, moderation actions, or feeds)

- [ ] Every new UGC surface passes the scan before other users can see it; cite the gate at `<path:line>`.
- [ ] Scan runs BOTH an automated classifier AND a known-illegal hash-match; cite both at `<path:line>`.
- [ ] Hash-match routes to the isolated illegal-content path: mandatory report + evidence preservation + account lockdown, never silent delete; cite at `<path:line>`.
- [ ] Borderline content routes to a human-review queue, not auto-publish/auto-remove.
- [ ] Every moderation action is attributed (actor or named rule) + reasoned + audited BEFORE effect; cite the audit write at `<path:line>`.
- [ ] Every action has an appeal/reversal path; appeal is decided by a different actor.
- [ ] Reporter PII is never serialized to the reported user; cite the target-facing serializer at `<path:line>`.
- [ ] Reports are rate-limited per reporter, deduped per (reporter, target), and brigade-resistant on auto-action.
- [ ] Edit re-runs the scan idempotently; approved-then-edited content cannot bypass it; cite at `<path:line>`.
- [ ] Shadow-ban is enforced server-side on read and leaks no signal to the shadowed user.
- [ ] Moderator capability is scoped least-privilege and attributed to an individual; no shared moderator account.
- [ ] Scanner fails CLOSED (hold for review) on error, never fail-open to publish.

## Anti-patterns

- **Publish-then-maybe-scan** — `await posts.create(body); return post;` with the scan on a best-effort async job that may never run -> illegal/abusive content is live the instant it's created. Gate distribution on the scan result.
- **Classifier-only, no hash-match** — an NSFW model scores an uploaded image "0.2 safe" and it ships; it was a known CSAM hash all along. A clean classifier score NEVER substitutes for the known-illegal hash corpus.
- **Silent-delete illegal content** — a CSAM hit is `await media.delete(id)` and the row is gone. Evidence destroyed, no report filed -> legal liability + obstruction. Isolated path: lock + preserve + report, never delete.
- **Unattributed ban** — `await users.update(id, { banned: true })` with no actor, no reason, no audit row -> nobody can say who banned this user or why, and it can't be defended on appeal. Attribute + reason + audit before effect.
- **No appeal** — a ban with no reversal route -> a wrongly-banned user has no due process and support reverses bans by raw SQL with no audit. Every action gets an appeal item + an audited reversal.
- **Self-review appeal** — the moderator who issued the ban also decides the appeal -> the appeal is theatre. Route appeals to a different actor.
- **Report count auto-removes** — `if (reportCount >= 5) remove()` with no dedup / no weighting -> five sock-puppets brigade any post off the platform. Dedup per (reporter,target), rate-limit per reporter, weight against coordination.
- **Reporter doxx** — the "reported by" field is serialized into the target's notification -> the reported user retaliates against the reporter. Reporter PII never reaches the target.
- **Edit bypass** — content is approved, the author edits it to abusive content, and the edit path doesn't re-scan -> approval laundering. Re-scan idempotently on every edit.
- **Shadow leak** — the shadowed user's post shows "0 views" while everyone else's shows real counts -> they infer the shadow-ban. Mirror the author's own view; leak no differential signal.
- **Fail-open scanner** — the classifier times out and the code `catch` publishes anyway -> a scanner outage becomes an open firehose of unmoderated content. Fail closed: hold for review.
- **Over-privileged moderator** — a content moderator's token can also delete accounts and read DMs platform-wide -> a compromised moderator is a platform compromise. Scope moderator capability to the moderation surface.

## Enforcement

- `<commands-path>/audit-moderation.md` (slash: `/audit-moderation`) — traces where UGC enters at `<path:line>`, asserts scan coverage (pre/post-publish + edit re-scan), illegal-content handling (hash-match + mandatory report + evidence preservation), action audit/attribution, appeal path, reporter-PII shielding, report rate-limit, and moderator over-privilege — cite-or-halt, never an assumed pipeline.
- `<agents-path>/moderation-reviewer.md` — review gate hard-failing on unscanned UGC, classifier-only scanning, silent-deleted illegal content, unattributed/un-audited actions, missing appeal path, reporter-PII exposure, report brigading, edit scan-bypass, fail-open scanners, and shadow-ban leaks.
- CI lint MUST flag any UGC create/update path (post/comment/upload/message) that reaches a feed/search/notify surface without passing the moderation pipeline (AST heuristic; flag for review).
- CI lint MUST flag a `delete` on flagged-illegal content that is not on the isolated preserve+report path.
- CI MUST assert moderation-action handlers write an audit entry (actor + reason + evidenceRef) — fail the build on an action handler with no audit call.
- CI MUST assert the target-facing report serializer does not include the reporter id / PII fields (allowlist check).
- TODO: `scripts/validate-moderation-coverage.sh` to walk UGC surfaces and assert each one routes through the scan (pre/post + edit), each action audits + is appealable, and the illegal-content path preserves+reports.

## Cross-references

- `<patterns-path>/moderation-pipeline.md` — scan (classifier + hash-match) → queue → audited+attributed action → appeal, with the illegal-content preserve+report hook, reporter-PII shielding, rate-limited reporting, and idempotent edit re-scan code shapes.
- `<rules-path>/audit-log` — every moderation action is an audited, append-only, attributed event; what to record per action.
- `<rules-path>/admin` — moderator tooling is scoped admin actions; least-privilege + per-individual attribution.
- `<rules-path>/rate-limit` — per-reporter / per-target report rate limiting + brigading resistance.
- `<rules-path>/media-processing` — image/video decode + thumbnail + hashing handoff that the scan consumes.
- `<rules-path>/compliance` — the legal/reporting regime (CSAM mandatory reporting, evidence preservation, retention, jurisdiction).
- `<commands-path>/audit-moderation.md` — diagnostic command.
- `<agents-path>/moderation-reviewer.md` — review gate.
- `<adr-path>/<NNN>-moderation-policy.md` — ADR pinning the policy thresholds, classifier/hash providers, queue SLA, and the mandatory-reporting jurisdiction + retention contract.

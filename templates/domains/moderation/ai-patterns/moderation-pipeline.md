---
name: moderation-pipeline
description: "Pattern: Moderation pipeline (scan, queue, audited action, appeal)"
kind: ai-pattern
---

# Pattern: Moderation pipeline (scan, queue, audited action, appeal)

> **Hard rule** — User-generated content is SCANNED before it reaches other users (classifier + known-illegal hash-match); a hash-match is NOT a normal decision — it routes to an isolated path that PRESERVES evidence, files a MANDATORY report, and locks the account, never a silent delete; borderline content goes to a human-review queue; every moderation action is ATTRIBUTED to a real actor (or named rule), carries a reason + evidence, and is AUDITED before it takes effect; every action has an APPEAL/reversal path decided by a different actor; the reporter's identity is NEVER exposed to the reported user; reports are RATE-LIMITED + brigade-resistant; and edits RE-SCAN idempotently.

**When to apply**
- Any surface where users post content others can see: posts, comments, images, video, DMs that can be reported, profiles, reviews, uploads.
- Multi-user products where unscanned content reaching the feed/search/notify layer is a trust-and-safety + legal exposure.
- Anywhere the platform can host the known-illegal corpus risk (image/video upload) — the hash-match + mandatory-reporting path is non-negotiable there.

**When NOT to apply**
- Author-only private content that is never distributed and never reportable (a private draft) — scan on the transition to visible, not on draft save.
- A fully closed system with no user-to-user content (an internal dashboard) — there is no UGC to moderate.
- Trusted first-party editorial content published through an authoring workflow with its own human sign-off — that IS the human review; don't double-gate, but DO still hash-match uploads.

**Halt conditions / mandatory cites**
- Cite the scan gate (classifier + hash-match) between UGC creation and distribution at `<path:line>`. UGC reaching a feed/search/notify surface with no scan = halt.
- Cite the isolated illegal-content path — preserve evidence + mandatory report + lockdown — at `<path:line>`. A hash-match that silently deletes, or drops into the normal queue, = halt.
- Cite the human-review queue route for borderline content at `<path:line>`. Auto-publish or auto-remove of uncertain-band content = halt.
- Cite the audited + attributed action write at `<path:line>`. A moderation action with no actor / reason / audit entry = halt.
- Cite the appeal/reversal path at `<path:line>`. A ban/removal with no appeal route = halt.
- Cite the target-facing serializer proving reporter PII is absent at `<path:line>`. Reporter id reachable by the reported user = halt.
- Cite the report rate-limit + (reporter,target) dedup + brigading guard at `<path:line>`, and the idempotent edit re-scan at `<path:line>`.
- Grep ban: "content is moderated / safe" without file:line for the scan gate, the illegal-content path, the audited action, and the reporter-PII serializer.

## Why

UGC moderation is the one workload that is simultaneously a legal obligation, a trust boundary, and a due-process system. The recurring failure modes:

1. **Unscanned content ships** — content is created and distributed before (or without) any scan, so illegal or abusive material is served to users the instant it's posted. The scan must GATE distribution, not trail it.
2. **Illegal content is mishandled** — a CSAM hash-match is treated as a normal "remove" and silently deleted, destroying the evidence and skipping the mandatory report. Known-illegal content has its own isolated, audited, evidence-preserving, reporting path.
3. **Bans are unaccountable** — a user is removed with no actor, no reason, no audit, and no appeal. Moderation is a due-process system: attribute, reason, audit, and make every action reversible by a different actor.
4. **The system is weaponized** — reporters are doxxed to their targets (retaliation), or a coordinated group brigades a false-flag takedown. Shield reporter PII; rate-limit + weight reports against coordination.

The pattern: define a closed action vocabulary, scan on every ingest + edit (classifier + hash-match), branch the illegal-content path off to preserve+report, queue the borderline band for humans, and make every action attributed + audited + appealable, with reporter PII physically separated from target-facing views.

> The TypeScript below uses NestJS-style decorators + helpers (`@Ctx`, repository `findOrThrow`, an injected queue) for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework, the lookup-or-throw helper, the DI mechanism. The SHAPE — scan before distribute, branch illegal content to an isolated preserve+report path, queue the borderline band, attribute+audit every action, expose an appeal, and shield reporter PII — is what's universal, not the helper names.

## The moderation contract (declarative)

```ts
// src/modules/moderation/core/moderation.types.ts

/** Closed action vocabulary — each declares reversibility + whether a reason/evidence is required. */
export const MODERATION_ACTIONS = {
  remove:        { reversible: true,  requiresReason: true,  requiresEvidence: true  },
  restore:       { reversible: false, requiresReason: true,  requiresEvidence: false },
  ban:           { reversible: true,  requiresReason: true,  requiresEvidence: true  },
  unban:         { reversible: false, requiresReason: true,  requiresEvidence: false },
  shadow:        { reversible: true,  requiresReason: true,  requiresEvidence: true  },
  unshadow:      { reversible: false, requiresReason: true,  requiresEvidence: false },
  age_gate:      { reversible: true,  requiresReason: true,  requiresEvidence: false },
  report_illegal:{ reversible: false, requiresReason: true,  requiresEvidence: true  }, // isolated path
} as const;
export type ModerationAction = keyof typeof MODERATION_ACTIONS;

export type ScanVerdict =
  | { decision: 'clear' }                                   // classifier clean, no hash hit -> publish
  | { decision: 'queue'; band: 'borderline'; signals: ScanSignals }  // -> human review
  | { decision: 'block'; reason: string; signals: ScanSignals }      // policy violation -> withhold
  | { decision: 'illegal'; corpus: 'csam' | 'terror'; hashMatch: HashMatch }; // -> isolated path

export interface ScanSignals {
  classifier: { score: number; labels: string[]; modelVersion: string };
  hashMatch: HashMatch | null;
  policyVersion: string;
}
export interface HashMatch { algo: 'photodna' | 'pdq' | 'md5'; hash: string; corpus: 'csam' | 'terror'; }
```

The closed vocabulary — not ad-hoc boolean flags — is what feature code uses. Reversibility, required reason, and required evidence are derived from it.

## The scanner: classifier + known-illegal hash-match (both)

```ts
// src/modules/moderation/core/scanner.ts

export class Scanner {
  constructor(
    private classifier: ContentClassifier,   // text-toxicity / nudity / spam model
    private hashIndex: IllegalHashIndex,      // PhotoDNA / PDQ corpus (CSAM, terror)
    private policy: PolicyConfig,
  ) {}

  /** Idempotency key shape — identical content short-circuits an already-computed verdict. */
  scanKey(contentId: string, contentHash: string): string {
    return `scan:${contentId}:${contentHash}`;
  }

  async scan(content: ScanInput): Promise<ScanVerdict> {
    // 1) Known-illegal hash-match FIRST. A hit is decisive and bypasses the classifier entirely —
    //    a "clean" classifier score must NEVER be able to override a known-illegal match.
    if (content.media) {
      const hashMatch = await this.hashIndex.match(content.media); // perceptual + crypto hashes
      if (hashMatch) {
        return { decision: 'illegal', corpus: hashMatch.corpus, hashMatch };
      }
    }

    // 2) Automated classifier for policy-grade content.
    const c = await this.classifier.classify(content); // { score, labels, modelVersion }
    const signals: ScanSignals = {
      classifier: c,
      hashMatch: null,
      policyVersion: this.policy.version, // stamp the policy + model versions onto the verdict
    };

    if (c.score >= this.policy.blockThreshold) {
      return { decision: 'block', reason: c.labels.join(','), signals };
    }
    if (c.score >= this.policy.reviewThreshold) {
      return { decision: 'queue', band: 'borderline', signals }; // uncertain band -> humans
    }
    return { decision: 'clear' };
  }
}
```

Two distinct signals. The hash-match runs first and is decisive; the classifier never launders a known-illegal item to "clear".

## Ingest: scan gates distribution, edit re-scans idempotently

```ts
// src/modules/moderation/moderation.service.ts

@Injectable()
export class ModerationService {
  constructor(
    @Inject(SCANNER) private scanner: Scanner,
    @Inject(QUEUE) private queue: ReviewQueue,
    @Inject(ILLEGAL) private illegal: IllegalContentPipeline,
    @Inject(SCAN_CACHE) private scanCache: ScanCache,     // idempotency
    @Inject(AUDIT_LOG) private audit: AuditLog,
  ) {}

  /** Called on CREATE and on every EDIT. Distribution is gated on the returned visibility. */
  async ingest(content: UgcContent): Promise<{ visibility: 'public' | 'author_only' | 'withheld' }> {
    const key = this.scanner.scanKey(content.id, content.contentHash);

    // Idempotent re-scan: identical content (same hash) returns the prior verdict. An EDIT changes
    // the hash, so it MUST be re-scanned — approved-then-edited content can never bypass the scan.
    const verdict = await this.scanCache.getOrCompute(key, () => this.scanner.scan(content));

    switch (verdict.decision) {
      case 'illegal':
        // ISOLATED path — never a normal remove, never a silent delete.
        await this.illegal.handle(content, verdict.hashMatch);
        return { visibility: 'withheld' };

      case 'block':
        await this.audit.record({
          action: 'remove', actorId: null, ruleId: `auto:${verdict.signals.classifier.modelVersion}`,
          targetId: content.authorId, contentId: content.id,
          reason: verdict.reason, evidenceRef: key, at: new Date(),
        });
        return { visibility: 'withheld' };

      case 'queue':
        // Borderline: visible to AUTHOR ONLY until a human decides. Never auto-published, never auto-removed.
        await this.queue.enqueue({ contentId: content.id, signals: verdict.signals, slaHours: 24 });
        return { visibility: 'author_only' };

      case 'clear':
        return { visibility: 'public' }; // only a cleared verdict reaches other users
    }
  }
}
```

Distribution is a function of the scan verdict. `author_only` and `withheld` content never reaches the feed; only `clear` does. The edit path runs the exact same `ingest`, so an edit re-scans by construction.

## The isolated illegal-content path: preserve, report, lock — never delete

```ts
// src/modules/moderation/core/illegal-content.pipeline.ts

export class IllegalContentPipeline {
  constructor(
    private evidence: EvidenceVault,   // write-once, legal-hold, NOT the normal media store
    private reporter: MandatoryReporter, // NCMEC / national CSAM authority client
    private accounts: AccountService,
    private audit: AuditLog,
  ) {}

  /**
   * A known-illegal hash-match. This path NEVER deletes the content — deleting it destroys the
   * legal record and is itself an offence. It preserves, reports, locks, and audits.
   */
  async handle(content: UgcContent, hashMatch: HashMatch): Promise<void> {
    // 1) PRESERVE — write-once snapshot of content + metadata + uploader identity under legal hold.
    const evidenceRef = await this.evidence.preserve({
      contentId: content.id,
      bytes: content.media!,            // the actual file, retained per the legal retention window
      uploaderId: content.authorId,
      uploaderIp: content.uploaderIp,
      hashMatch,
      capturedAt: new Date(),
    });

    // 2) LOCK the account immediately — stop further uploads from this actor.
    await this.accounts.lockdown(content.authorId, { reason: 'illegal_content', evidenceRef });

    // 3) MANDATORY REPORT to the authority. See `<rules-path>/compliance` for the jurisdiction + SLA.
    await this.reporter.fileReport({
      corpus: hashMatch.corpus, hashMatch, evidenceRef,
      uploaderId: content.authorId, uploaderIp: content.uploaderIp,
    });

    // 4) Withhold from all surfaces (NOT delete) + audit on the isolated trail.
    await this.audit.record({
      action: 'report_illegal', actorId: null, ruleId: `hashmatch:${hashMatch.algo}`,
      targetId: content.authorId, contentId: content.id,
      reason: `known_illegal:${hashMatch.corpus}`, evidenceRef, at: new Date(),
    });
    // NO `media.delete(...)` here. Removal of preserved evidence happens only on legal release.
  }
}
```

Silent deletion is the cardinal error: it destroys evidence and skips the mandatory report. Preserve, lock, report, withhold — on an audited, isolated trail.

## Audited + attributed action, decided by a real actor

```ts
// src/modules/moderation/moderation-action.service.ts

@Injectable()
export class ModerationActionService {
  constructor(
    @Inject(AUDIT_LOG) private audit: AuditLog,
    @Inject(MOD_REPO) private repo: ModerationRepo,
  ) {}

  /** Every human moderation action goes through here — attributed, reasoned, audited BEFORE effect. */
  async act(cmd: ModerationCommand, ctx: ModeratorContext): Promise<void> {
    const spec = MODERATION_ACTIONS[cmd.action];

    // Moderator capability is scoped — see `<rules-path>/admin`. A moderator can only act on content
    // within their assigned scope, and the action is attributed to THEM, never a shared account.
    assertModeratorScope(ctx, cmd.targetSurface); // throws ForbiddenError if out of scope

    if (spec.requiresReason && !cmd.reason) throw new ValidationError('reason_required');
    if (spec.requiresEvidence && !cmd.evidenceRef) throw new ValidationError('evidence_required');

    // Audit BEFORE the action takes effect — an action with no audit row never happens.
    await this.audit.record({
      action: cmd.action,
      actorId: ctx.moderatorId,        // a real, individual moderator — never "system", never shared
      targetId: cmd.targetId, contentId: cmd.contentId,
      reason: cmd.reason, evidenceRef: cmd.evidenceRef ?? null, at: new Date(),
    });

    await this.repo.apply(cmd); // remove / ban / shadow / age_gate ...
  }
}
```

The audit write precedes the effect. The actor is an individual moderator with a scoped capability. There is no unattributed ban.

## Appeal / reversal — due process, different actor

```ts
// src/modules/moderation/appeal.service.ts

@Injectable()
export class AppealService {
  /** Every reversible action against a user is appealable. */
  async openAppeal(targetId: string, actionId: string, statement: string): Promise<Appeal> {
    const action = await this.repo.findActionOrThrow(actionId);
    if (!MODERATION_ACTIONS[action.action].reversible) {
      throw new NotAppealableError(action.action);
    }
    return this.appeals.create({ actionId, targetId, statement, status: 'open' });
  }

  /** Appeal is decided by a DIFFERENT actor than the one who issued the original action — no self-review. */
  async decideAppeal(appealId: string, decision: 'upheld' | 'reversed', ctx: ModeratorContext): Promise<void> {
    const appeal = await this.appeals.findOrThrow(appealId);
    const original = await this.repo.findActionOrThrow(appeal.actionId);
    if (original.actorId && original.actorId === ctx.moderatorId) {
      throw new SelfReviewError('appeal must be decided by a different moderator');
    }

    if (decision === 'reversed') {
      await this.actions.act(                       // the reversal is itself an audited action
        { action: reverseOf(original.action), targetId: appeal.targetId,
          contentId: original.contentId, reason: `appeal_reversed:${appealId}` },
        ctx,
      );
    }
    await this.appeals.close(appealId, { decision, decidedBy: ctx.moderatorId });
  }
}
```

Every reversible action gets an appeal; the appeal is decided by someone other than the original actor; a reversal restores state and is itself audited.

## Reporter PII shielding + rate-limited, brigade-resistant reporting

```ts
// src/modules/moderation/report.service.ts

@Injectable()
export class ReportService {
  constructor(
    @Inject(RATE_LIMITER) private limiter: RateLimiter,    // see `<rules-path>/rate-limit`
    @Inject(REPORT_REPO) private reports: ReportRepo,
    @Inject(QUEUE) private queue: ReviewQueue,
  ) {}

  async submitReport(reporterId: string, targetContentId: string, reason: string): Promise<void> {
    // Anti-brigading: per-reporter rate limit + per-(reporter,target) dedup so one actor can't spam
    // and a coordinated group can't auto-trigger a takedown by raw count.
    await this.limiter.consume(`report:reporter:${reporterId}`);            // per-reporter cap
    if (await this.reports.exists(reporterId, targetContentId)) return;     // dedup per (reporter,target)

    await this.reports.create({ reporterId, targetContentId, reason }); // reporterId stored INTERNALLY only

    // Weighted aggregation resists coordination — raw count never auto-removes. Distinct, trusted,
    // historically-accurate reporters carry more weight; bursts from new/correlated accounts carry less.
    const weight = await this.reports.weightedScore(targetContentId);
    if (weight >= ESCALATION_THRESHOLD) {
      await this.queue.enqueue({ contentId: targetContentId, signals: { reportWeight: weight }, slaHours: 6 });
    }
  }
}

// src/modules/moderation/serializers/report.target-view.ts
//
// The TARGET-facing view of a report. The reporter's identity is NEVER serialized here — the reported
// user must not learn who reported them (retaliation). Reporter PII lives only on the internal/audit view.
export function toTargetReportView(report: ReportRecord): TargetReportView {
  return {
    contentId: report.targetContentId,
    reason: report.reason,        // the policy reason, not the reporter
    status: report.status,
    // NO reporterId, NO reporter email, NO reporter handle — physically absent from this serializer.
  };
}
```

Reporter id is internal-only. Reports are rate-limited + deduped + weighted, so a brigade can't auto-remove content by volume. The target-facing serializer cannot leak the reporter.

## Shadow-ban: server-side, leak-proof

```ts
// src/modules/moderation/visibility.ts

/** Shadow-ban is enforced on READ, server-side. The shadowed author sees their own content normally;
 *  everyone else sees nothing — and the author is given NO differential signal (counts, shape, timing). */
export function visibleTo(content: ContentRow, viewer: Viewer): boolean {
  if (!content.shadowed) return true;
  return viewer.userId === content.authorId; // author sees it; nobody else does
}

// When rendering the author's own feed, mirror the SAME numbers they'd see if not shadowed —
// never expose "0 views" / "hidden" / a different error so they cannot infer the shadow state.
```

The shadow flag never leaks back to the shadowed user through counts, response shape, timing, or errors.

## Common mistakes

### Publish-then-maybe-scan
`await posts.create(body); enqueueScan(post.id)` — the post is live before the scan runs (or if it fails). Gate distribution on the verdict; only `clear` is public.

### Classifier-only, no hash-match
Relying on an NSFW model alone misses known-illegal content the model scores "safe". Hash-match the known-illegal corpus FIRST; it's decisive.

### Silent-delete illegal content
`await media.delete(id)` on a CSAM hit destroys evidence and skips the mandatory report. Preserve (write-once), lock, report, withhold — never delete.

### Unattributed / un-audited action
`users.update(id, { banned: true })` with no actor/reason/audit is an unaccountable ban with nothing to defend on appeal. Attribute + reason + audit before effect.

### No appeal / self-review appeal
A ban with no reversal route, or an appeal decided by the original moderator, is not due process. Every reversible action is appealable, by a different actor.

### Report-count auto-remove
`if (count >= 5) remove()` lets five sock-puppets brigade any post. Dedup per (reporter,target), rate-limit per reporter, weight against coordination.

### Reporter doxx
Serializing "reported by <user>" into the target's view invites retaliation. Reporter PII lives only on internal/audit views.

### Edit bypass
Re-scanning only on create lets an author approve clean content then edit it to abuse. Re-scan idempotently on every edit (the content hash changes).

### Fail-open scanner
`catch { publish() }` turns a scanner outage into an unmoderated firehose. Fail CLOSED — hold for review on error.

### Shadow leak
Showing the shadowed author "0 views" while others see real counts reveals the shadow-ban. Mirror their own normal view; leak no differential.

## Cross-references

- `<rules-path>/moderation-discipline.md` — the hard-rule list (scan before serve, hash-match + mandatory report, audited+attributed action, appeal, reporter PII, rate-limit, edit re-scan, shadow leak).
- `<rules-path>/audit-log` — every moderation action is an audited, append-only, attributed event.
- `<rules-path>/admin` — moderator tooling = scoped, least-privilege, per-individual admin actions.
- `<rules-path>/rate-limit` — per-reporter / per-target report rate limiting + brigading resistance.
- `<rules-path>/media-processing` — image/video decode + hashing handoff the scanner consumes.
- `<rules-path>/compliance` — CSAM mandatory-reporting jurisdiction, evidence retention, and legal-hold contract.
- `<commands-path>/audit-moderation.md` — diagnostic that traces ingest → scan → queue → action → appeal.
- `<agents-path>/moderation-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-moderation-policy.md` — ADR pinning policy thresholds, classifier/hash providers, queue SLA, and the mandatory-reporting + retention contract.
